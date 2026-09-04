use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::thread;
use std::time::Duration;

use anyhow::{Result, ensure};
use clap::{Parser, Subcommand};
use sha2::{Digest, Sha256};
use walkdir::WalkDir;

use crate::check;
use crate::downstream;
use crate::format;
use crate::measure;
use crate::opportunity;
use crate::public;
use crate::render::{self, Compiler};
use crate::skills;
use crate::stations;
use crate::workspace::Workspace;

#[derive(Debug, Parser)]
#[command(
    name = "ccvl",
    version,
    about = "Deterministic CV and cover-letter compiler"
)]
struct Args {
    #[arg(long, global = true, value_name = "DIRECTORY")]
    root: Option<PathBuf>,
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Verify the self-contained binary and workspace.
    Setup,
    /// Show what the dependency-free setup requires.
    Bootstrap,
    /// Report the embedded runtime and workspace.
    Doctor,
    /// Run every deterministic workspace and document check.
    Check,
    /// Check station coverage and MECE ownership.
    ProfileStatus {
        #[arg(default_value = "cvl/general/stations.json")]
        plan: PathBuf,
        #[arg(long)]
        verify_sources: bool,
    },
    /// Measure the general CV and cover letter.
    Measure {
        #[arg(long)]
        all: bool,
    },
    /// Measure one keyed opportunity.
    MeasureOpportunity {
        organisation_key: String,
        position_key: String,
        #[arg(long)]
        all: bool,
    },
    /// Run all checks required before publishing.
    PublicCheck,
    /// Verify that a private downstream differs only in explicitly owned paths.
    DownstreamCheck {
        #[arg(long, default_value = "ccvl-downstream.json")]
        policy: PathBuf,
        #[arg(long)]
        upstream_ref: Option<String>,
    },
    /// Build every general CV preset and both cover letters.
    Build,
    /// Create one keyed opportunity without overwriting an existing record.
    NewOpportunity {
        organisation_key: String,
        position_key: String,
    },
    /// Build one CV.
    BuildCv {
        locale: String,
        #[arg(default_value_t = 4)]
        pages: usize,
        #[arg(long)]
        application: Option<PathBuf>,
        #[arg(long)]
        profile: Option<PathBuf>,
        #[arg(long)]
        output: Option<PathBuf>,
    },
    /// Build one cover letter.
    BuildCl {
        locale: String,
        #[arg(long)]
        application: Option<PathBuf>,
        #[arg(long)]
        profile: Option<PathBuf>,
        #[arg(long)]
        output: Option<PathBuf>,
    },
    /// Build one keyed opportunity package.
    BuildOpportunity {
        organisation_key: String,
        position_key: String,
    },
    /// Rebuild one CV whenever its inputs change.
    WatchCv {
        locale: String,
        #[arg(default_value_t = 4)]
        pages: usize,
    },
    /// Format Typst sources with the embedded formatter.
    Fmt {
        #[arg(long)]
        check: bool,
    },
    /// Run the strict small-model skill evaluation.
    SkillEval {
        #[arg(long, default_value = "tests/skill-cases.json")]
        cases: PathBuf,
        #[arg(long, default_value = ".agents/skills")]
        skills_root: PathBuf,
        #[arg(long, default_value = "tmp/ai-skill-eval/report.json")]
        output: PathBuf,
        #[arg(long)]
        response_file: Option<PathBuf>,
        #[arg(long)]
        summary: Option<PathBuf>,
        #[arg(long)]
        model: Option<String>,
    },
}

pub fn run() -> Result<ExitCode> {
    let args = Args::parse();
    let workspace = Workspace::discover(args.root.as_deref())?;
    let mut exit_code = ExitCode::SUCCESS;
    match args.command {
        Command::Setup => {
            doctor(&workspace)?;
            check::run(&workspace)?;
            println!("ccvl is ready. No external runtime or fonts are required.");
        }
        Command::Bootstrap => {
            println!("ccvl bootstrap plan");
            println!(
                "platform: {}-{}",
                std::env::consts::OS,
                std::env::consts::ARCH
            );
            println!("runtime dependencies: none");
            println!("embedded: Typst 0.15.1 | Typstyle 0.15.1 | 16 font files");
        }
        Command::Doctor => doctor(&workspace)?,
        Command::Check => {
            check::run(&workspace)?;
            println!(
                "All data, station, source, skill, font, reproducibility, CV, and cover-letter checks passed."
            );
        }
        Command::ProfileStatus {
            plan,
            verify_sources,
        } => {
            let path = workspace.existing_inside(plan)?;
            let document = stations::load_plan(&workspace, &path)?;
            let assessment = stations::assess(
                &workspace,
                &document,
                &workspace.relative(&path)?.display().to_string(),
            )?;
            if verify_sources && assessment.ready() {
                stations::validate_general(&workspace, true)?;
            }
            println!("{}", stations::format_report(&workspace, &assessment)?);
            ensure!(assessment.ready(), "station plan is not ready");
        }
        Command::Measure { all } => {
            let failures =
                measure::measure(&workspace, &measure::general_specs(&workspace)?, all, true)?;
            ensure!(
                failures.is_empty(),
                "{} line-contract failure(s)",
                failures.len()
            );
        }
        Command::MeasureOpportunity {
            organisation_key,
            position_key,
            all,
        } => {
            let specs = measure::keyed_specs(&workspace, &organisation_key, &position_key)?;
            let failures = measure::measure(&workspace, &specs, all, true)?;
            ensure!(
                failures.is_empty(),
                "{} line-contract failure(s)",
                failures.len()
            );
        }
        Command::PublicCheck => {
            check::run(&workspace)?;
            public::validate_boundary(&workspace)?;
            println!(
                "Public-boundary checks passed. Review PUBLIC_IDENTIFIERS.md before publishing."
            );
        }
        Command::DownstreamCheck {
            policy,
            upstream_ref,
        } => downstream::validate(&workspace, &policy, upstream_ref.as_deref())?,
        Command::Build => print_outputs(render::render_general(&workspace)?),
        Command::NewOpportunity {
            organisation_key,
            position_key,
        } => {
            let path = opportunity::create_record(&workspace, &organisation_key, &position_key)?;
            println!("Created {}", workspace.relative(&path)?.display());
        }
        Command::BuildCv {
            locale,
            pages,
            application,
            profile,
            output,
        } => {
            stations::validate_general(&workspace, true)?;
            let locale = render::normalize_locale(&locale)?;
            let application = workspace.existing_inside(application.unwrap_or_else(|| {
                PathBuf::from(format!("cvl/general/{locale}/application.json"))
            }))?;
            let profile = workspace.existing_inside(
                profile.unwrap_or_else(|| PathBuf::from("cvl/general/profile.json")),
            )?;
            let output = if let Some(output) = output {
                output
            } else {
                let preset = render::cv_preset(pages)?;
                workspace.path(format!("cvl/cv/output/{locale}/{preset}/cv.pdf"))
            };
            let spec = render::cv_spec(&workspace, locale, pages, &application, &profile, &output)?;
            print_outputs(vec![Compiler::new(&workspace)?.render(&workspace, &spec)?]);
        }
        Command::BuildCl {
            locale,
            application,
            profile,
            output,
        } => {
            let locale = render::normalize_locale(&locale)?;
            let application = workspace.existing_inside(application.unwrap_or_else(|| {
                PathBuf::from(format!("cvl/general/{locale}/application.json"))
            }))?;
            let profile = workspace.existing_inside(
                profile.unwrap_or_else(|| PathBuf::from("cvl/general/profile.json")),
            )?;
            let output =
                output.unwrap_or_else(|| workspace.path(format!("cvl/cl/output/{locale}/cl.pdf")));
            let spec = render::cl_spec(&workspace, locale, &application, &profile, &output)?;
            print_outputs(vec![Compiler::new(&workspace)?.render(&workspace, &spec)?]);
        }
        Command::BuildOpportunity {
            organisation_key,
            position_key,
        } => print_outputs(render::render_opportunity(
            &workspace,
            &organisation_key,
            &position_key,
        )?),
        Command::WatchCv { locale, pages } => watch_cv(&workspace, &locale, pages)?,
        Command::Fmt { check } => format::format_typst(&workspace, check)?,
        Command::SkillEval {
            cases,
            skills_root,
            output,
            response_file,
            summary,
            model,
        } => {
            let cases = resolve(&workspace, &cases);
            let skills_root = resolve(&workspace, &skills_root);
            let output = resolve(&workspace, &output);
            let response_file = response_file
                .as_deref()
                .map(|path| resolve(&workspace, path));
            let summary = summary.as_deref().map(|path| resolve(&workspace, path));
            let model = model
                .or_else(|| std::env::var("GROQ_MODEL").ok())
                .unwrap_or_else(|| skills::DEFAULT_MODEL.to_owned());
            let outcome = skills::run_hosted_evaluation(
                &workspace,
                &cases,
                &skills_root,
                &output,
                response_file.as_deref(),
                &model,
                summary.as_deref(),
            )?;
            println!(
                "Skill evaluation report: {} ({})",
                output.display(),
                outcome.status()
            );
            exit_code = ExitCode::from(outcome.exit_code());
        }
    }
    Ok(exit_code)
}

fn doctor(workspace: &Workspace) -> Result<()> {
    ensure!(
        ctypst::fonts::documents().len() == 16,
        "embedded font set is incomplete"
    );
    println!("ccvl {}", env!("CARGO_PKG_VERSION"));
    println!(
        "platform: {}-{}",
        std::env::consts::OS,
        std::env::consts::ARCH
    );
    println!("workspace: {}", workspace.root().display());
    println!("Typst engine: embedded 0.15.1");
    println!("Typstyle formatter: embedded 0.15.1");
    println!("fonts: 16 embedded files; system fonts disabled");
    println!("external runtime dependencies: none");
    Ok(())
}

fn watch_cv(workspace: &Workspace, locale: &str, pages: usize) -> Result<()> {
    let locale = render::normalize_locale(locale)?;
    println!("Watching ccvl sources for {locale} {pages}-page CV. Press Ctrl-C to stop.");
    let mut previous = Vec::new();
    loop {
        let current = source_digest(workspace)?;
        if current != previous {
            let spec = render::general_cv_spec(workspace, locale, pages)?;
            Compiler::new(workspace)?.render(workspace, &spec)?;
            println!("Rendered {}", spec.output.display());
            previous = current;
        }
        thread::sleep(Duration::from_millis(500));
    }
}

fn source_digest(workspace: &Workspace) -> Result<Vec<u8>> {
    let mut paths = WalkDir::new(workspace.path("cvl"))
        .into_iter()
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_file())
        .filter(|entry| {
            entry.path().extension().is_some_and(|extension| {
                extension == "typ" || extension == "json" || extension == "png"
            })
        })
        .map(walkdir::DirEntry::into_path)
        .collect::<Vec<_>>();
    paths.sort();
    let mut digest = Sha256::new();
    for path in paths {
        digest.update(path.to_string_lossy().as_bytes());
        digest.update(fs::read(path)?);
    }
    Ok(digest.finalize().to_vec())
}

fn print_outputs(outputs: Vec<PathBuf>) {
    for output in outputs {
        println!("Rendered {}", output.display());
    }
}

fn resolve(workspace: &Workspace, path: &Path) -> PathBuf {
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        workspace.path(path)
    }
}
