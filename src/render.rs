use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail, ensure};
use ctypst::{CompileRequest, Document, Engine, PageConstraint};
use serde_json::Value;

use crate::application::validate_line_contracts;
use crate::opportunity;
use crate::schema::validate_json_file;
use crate::stations;
use crate::workspace::Workspace;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DocumentKind {
    Cv,
    CoverLetter,
}

#[derive(Clone, Debug)]
pub struct DocumentSpec {
    pub name: String,
    pub kind: DocumentKind,
    pub source: PathBuf,
    pub output: PathBuf,
    pub inputs: BTreeMap<String, String>,
    pub expected_pages: usize,
}

pub struct Compiler {
    engine: Engine,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct OpportunityOptions {
    locale: &'static str,
    pages: usize,
    cover_letter: bool,
}

impl Compiler {
    pub fn new(workspace: &Workspace) -> Result<Self> {
        let engine = Engine::builder()
            .root(workspace.root())
            .fonts(ctypst::fonts::documents())
            .build()
            .context("cannot initialize embedded Typst engine")?;
        Ok(Self { engine })
    }

    pub fn compile(&self, workspace: &Workspace, spec: &DocumentSpec) -> Result<Document> {
        let source = workspace.relative(&workspace.existing_inside(&spec.source)?)?;
        let source = source.to_string_lossy().replace('\\', "/");
        self.engine
            .compile(
                CompileRequest::new(source)
                    .inputs(spec.inputs.clone())
                    .pages(PageConstraint::Exactly(spec.expected_pages)),
            )
            .map(|output| output.document)
            .with_context(|| format!("cannot compile {}", spec.name))
    }

    pub fn render(&self, workspace: &Workspace, spec: &DocumentSpec) -> Result<PathBuf> {
        let document = self.compile(workspace, spec)?;
        let bytes = self
            .engine
            .pdf(&document, source_date_epoch()?)
            .with_context(|| format!("cannot export {}", spec.name))?;
        ensure!(
            bytes.starts_with(b"%PDF-"),
            "Typst did not create a PDF for {}",
            spec.name
        );
        if let Some(parent) = spec.output.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("cannot create {}", parent.display()))?;
        }
        fs::write(&spec.output, bytes)
            .with_context(|| format!("cannot write {}", spec.output.display()))?;
        Ok(spec.output.clone())
    }
}

fn source_date_epoch() -> Result<i64> {
    let raw = std::env::var("SOURCE_DATE_EPOCH").unwrap_or_else(|_| "0".to_owned());
    let epoch = raw
        .parse::<i64>()
        .context("SOURCE_DATE_EPOCH must be a non-negative integer")?;
    ensure!(
        epoch >= 0,
        "SOURCE_DATE_EPOCH must be a non-negative integer"
    );
    Ok(epoch)
}

pub fn normalize_locale(value: &str) -> Result<&'static str> {
    match value.to_ascii_lowercase().as_str() {
        "de" | "de-ch" => Ok("de-ch"),
        "en" | "en-ch" => Ok("en-ch"),
        _ => bail!("unsupported locale: {value}"),
    }
}

pub fn cv_preset(pages: usize) -> Result<&'static str> {
    match pages {
        2 => Ok("twopager"),
        3 => Ok("threepager"),
        4 => Ok("fourpager"),
        _ => bail!("CV pages must be 2, 3, or 4: {pages}"),
    }
}

pub fn general_cv_spec(
    workspace: &Workspace,
    locale_value: &str,
    pages: usize,
) -> Result<DocumentSpec> {
    stations::validate_general(workspace, true)?;
    let locale = normalize_locale(locale_value)?;
    let preset = cv_preset(pages)?;
    let application = workspace.path(format!("cvl/general/{locale}/application.json"));
    let profile = workspace.path("cvl/general/profile.json");
    cv_spec(
        workspace,
        locale,
        pages,
        &application,
        &profile,
        &workspace.path(format!("cvl/cv/output/{locale}/{preset}/cv.pdf")),
    )
}

pub fn general_cl_spec(workspace: &Workspace, locale_value: &str) -> Result<DocumentSpec> {
    let locale = normalize_locale(locale_value)?;
    let application = workspace.path(format!("cvl/general/{locale}/application.json"));
    let profile = workspace.path("cvl/general/profile.json");
    cl_spec(
        workspace,
        locale,
        &application,
        &profile,
        &workspace.path(format!("cvl/cl/output/{locale}/cl.pdf")),
    )
}

pub fn cv_spec(
    workspace: &Workspace,
    locale: &str,
    pages: usize,
    application: &Path,
    profile: &Path,
    output: &Path,
) -> Result<DocumentSpec> {
    ensure!(
        (2..=4).contains(&pages),
        "CV pages must be 2, 3, or 4: {pages}"
    );
    Ok(DocumentSpec {
        name: format!("CV {locale}"),
        kind: DocumentKind::Cv,
        source: workspace.path(format!("cvl/cv/{locale}/main.typ")),
        output: output.to_path_buf(),
        inputs: BTreeMap::from([
            ("application".to_owned(), workspace.typst_path(application)?),
            ("cv-pages".to_owned(), pages.to_string()),
            ("profile".to_owned(), workspace.typst_path(profile)?),
        ]),
        expected_pages: pages,
    })
}

pub fn cl_spec(
    workspace: &Workspace,
    locale: &str,
    application: &Path,
    profile: &Path,
    output: &Path,
) -> Result<DocumentSpec> {
    Ok(DocumentSpec {
        name: format!("cover letter {locale}"),
        kind: DocumentKind::CoverLetter,
        source: workspace.path(format!("cvl/cl/{locale}/main.typ")),
        output: output.to_path_buf(),
        inputs: BTreeMap::from([
            ("application".to_owned(), workspace.typst_path(application)?),
            ("profile".to_owned(), workspace.typst_path(profile)?),
        ]),
        expected_pages: 1,
    })
}

pub fn compile_document(workspace: &Workspace, spec: &DocumentSpec) -> Result<Document> {
    Compiler::new(workspace)?.compile(workspace, spec)
}

pub fn render_spec(workspace: &Workspace, spec: &DocumentSpec) -> Result<PathBuf> {
    Compiler::new(workspace)?.render(workspace, spec)
}

pub fn render_general(workspace: &Workspace) -> Result<Vec<PathBuf>> {
    let compiler = Compiler::new(workspace)?;
    let mut outputs = Vec::new();
    for locale in ["de-ch", "en-ch"] {
        for pages in [2, 3, 4] {
            outputs.push(compiler.render(workspace, &general_cv_spec(workspace, locale, pages)?)?);
        }
        outputs.push(compiler.render(workspace, &general_cl_spec(workspace, locale)?)?);
    }
    Ok(outputs)
}

pub fn opportunity_specs(
    workspace: &Workspace,
    organisation: &str,
    position: &str,
) -> Result<Vec<DocumentSpec>> {
    stations::validate_general(workspace, true)?;
    let application = opportunity::record_path(workspace, organisation, position, true)?;
    let document = validate_json_file(
        &application,
        &workspace.path("schemas/application.schema.json"),
    )?;
    validate_line_contracts(
        workspace,
        &document,
        &workspace.relative(&application)?.display().to_string(),
        true,
    )?;
    let options = opportunity_options(&document)?;
    let locale = options.locale;
    let pages = options.pages;
    let cover_enabled = options.cover_letter;
    let output = application
        .parent()
        .context("application record has no parent")?
        .join("output");
    let profile = workspace.path("cvl/general/profile.json");
    let mut specs = vec![cv_spec(
        workspace,
        locale,
        pages,
        &application,
        &profile,
        &output.join("cv.pdf"),
    )?];
    specs[0].name = format!("CV {organisation}/{position}");
    if cover_enabled {
        let mut spec = cl_spec(
            workspace,
            locale,
            &application,
            &profile,
            &output.join("cl.pdf"),
        )?;
        spec.name = format!("cover letter {organisation}/{position}");
        specs.push(spec);
    }
    Ok(specs)
}

fn opportunity_options(document: &Value) -> Result<OpportunityOptions> {
    let locale = normalize_locale(
        document
            .pointer("/job/language")
            .and_then(Value::as_str)
            .unwrap_or_default(),
    )?;
    let pages = usize::try_from(
        document
            .pointer("/tailored_cv/pages")
            .and_then(Value::as_u64)
            .context("tailored_cv.pages is missing")?,
    )?;
    let cover_enabled = document
        .pointer("/tailored_cl/enabled")
        .and_then(Value::as_bool)
        .context("tailored_cl.enabled is missing")?;
    Ok(OpportunityOptions {
        locale,
        pages,
        cover_letter: cover_enabled,
    })
}

pub fn render_opportunity(
    workspace: &Workspace,
    organisation: &str,
    position: &str,
) -> Result<Vec<PathBuf>> {
    let specs = opportunity_specs(workspace, organisation, position)?;
    let output_dir = opportunity::record_path(workspace, organisation, position, true)?
        .parent()
        .context("record has no parent")?
        .join("output");
    remove_stale_cover_letter(
        &output_dir,
        specs
            .iter()
            .any(|spec| spec.kind == DocumentKind::CoverLetter),
    )?;
    let compiler = Compiler::new(workspace)?;
    specs
        .iter()
        .map(|spec| compiler.render(workspace, spec))
        .collect()
}

fn remove_stale_cover_letter(output_dir: &Path, cover_enabled: bool) -> Result<()> {
    if !cover_enabled {
        let stale = output_dir.join("cl.pdf");
        if stale.is_file() {
            fs::remove_file(stale)?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use super::*;

    #[test]
    fn page_counts_have_explicit_preset_names() {
        assert_eq!(cv_preset(2).unwrap(), "twopager");
        assert_eq!(cv_preset(3).unwrap(), "threepager");
        assert_eq!(cv_preset(4).unwrap(), "fourpager");
        assert!(cv_preset(1).is_err());
        assert!(cv_preset(5).is_err());
    }

    #[test]
    fn opportunity_record_selects_its_locale_pages_and_documents() {
        let workspace = Workspace::at(Path::new(env!("CARGO_MANIFEST_DIR"))).unwrap();
        let mut document = workspace
            .read_json("cvl/general/en-ch/application.json")
            .unwrap();
        document["job"]["language"] = "en-CH".into();
        document["tailored_cv"]["pages"] = 3.into();
        document["tailored_cl"] = serde_json::json!({"enabled": false});
        assert_eq!(
            opportunity_options(&document).unwrap(),
            OpportunityOptions {
                locale: "en-ch",
                pages: 3,
                cover_letter: false,
            }
        );
    }

    #[test]
    fn disabled_cover_letter_removes_stale_output() {
        let directory = tempdir().unwrap();
        let stale = directory.path().join("cl.pdf");
        fs::write(&stale, b"stale").unwrap();
        remove_stale_cover_letter(directory.path(), false).unwrap();
        assert!(!stale.exists());

        fs::write(&stale, b"current").unwrap();
        remove_stale_cover_letter(directory.path(), true).unwrap();
        assert!(stale.exists());
    }
}
