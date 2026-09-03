use anyhow::{Context, Result, ensure};
use serde_json::{Value, json};
use std::fs;
use tempfile::TempDir;

use crate::application;
use crate::format;
use crate::measure;
use crate::pdf;
use crate::public;
use crate::render::{Compiler, DocumentSpec, general_cl_spec, general_cv_spec};
use crate::skills;
use crate::stations;
use crate::workspace::Workspace;

pub fn run(workspace: &Workspace) -> Result<()> {
    validate_manifest(workspace)?;
    application::validate_profiles(workspace)?;
    application::validate_station_files(workspace)?;
    application::validate_all(workspace)?;
    skills::validate(workspace)?;
    public::validate_repository(workspace)?;
    format::format_typst(workspace, true)?;
    stations::validate_general(workspace, true)?;
    validate_embedded_fonts(workspace)?;
    let failures = measure::measure(workspace, &measure::general_specs(workspace)?, false, false)?;
    ensure!(
        failures.is_empty(),
        "line measurement failed: {}",
        failures.join("; ")
    );
    render_and_verify(workspace)
}

fn validate_manifest(workspace: &Workspace) -> Result<()> {
    let manifest = workspace.read_json("ccvl.json")?;
    ensure!(
        manifest.get("format") == Some(&Value::String("ccvl-workspace".to_owned()))
            && manifest.get("schema_version") == Some(&Value::from(4)),
        "ccvl.json: unsupported workspace format or schema version"
    );
    let expected_groups = json!({
        "cvl": {"root": "cvl", "general": "cvl/general", "profile": "cvl/general/profile.json", "stations": "cvl/general/stations.json", "de-CH": "cvl/general/de-ch/application.json", "en-CH": "cvl/general/en-ch/application.json"},
        "targets": {"root": "targets"},
        "opportunities": {"root": "opportunities", "path": "opportunities/<organisation-key>/<position-key>", "record": "application.json", "output": "output"}
    });
    ensure!(
        manifest.get("workspace_groups") == Some(&expected_groups),
        "ccvl.json: workspace groups must be cvl, targets, and keyed opportunities"
    );
    for relative in [
        "schemas/application.schema.json",
        "schemas/profile.schema.json",
        "schemas/stations.schema.json",
        "cvl/general/profile.json",
        "cvl/general/stations.json",
        "cvl/general/de-ch/application.json",
        "cvl/general/en-ch/application.json",
        "cvl/README.md",
        "targets/README.md",
        "opportunities/README.md",
        "cvl/cv/de-ch/main.typ",
        "cvl/cv/en-ch/main.typ",
        "cvl/cl/de-ch/main.typ",
        "cvl/cl/en-ch/main.typ",
    ] {
        ensure!(
            workspace.path(relative).is_file(),
            "ccvl.json: missing referenced file {relative}"
        );
    }
    ensure!(
        manifest.pointer("/documents/cv/presets") == Some(&json!([2, 3, 4])),
        "ccvl.json: CV presets must be [2, 3, 4]"
    );
    ensure!(
        manifest.pointer("/documents/cv/summary_lines") == Some(&Value::from(5)),
        "ccvl.json: every CV Summary must contain exactly five rendered lines"
    );
    let layout = manifest
        .pointer("/documents/cv/layout_contract")
        .context("ccvl.json has no CV layout contract")?;
    ensure!(
        layout.pointer("/page_1/entries")
            == Some(&json!({"minimum": 6, "target": 7, "maximum": 8})),
        "ccvl.json: page 1 contract changed"
    );
    ensure!(
        layout.pointer("/page_2") == Some(&json!({"entries": 10, "bullets_per_entry": 2})),
        "ccvl.json: page 2 contract changed"
    );
    ensure!(
        layout.pointer("/page_3") == Some(&json!({"entries": 10, "bullets_per_entry": 2})),
        "ccvl.json: page 3 contract changed"
    );
    ensure!(
        layout.pointer("/page_4")
            == Some(&json!({"groups": 3, "entries_per_group": 3, "bullets_per_entry": 3})),
        "ccvl.json: page 4 contract changed"
    );
    ensure!(
        layout.get("verified_only") == Some(&Value::Bool(true))
            && layout.get("unique_fact_assignment") == Some(&Value::Bool(true)),
        "ccvl.json: evidence or MECE guarantees were weakened"
    );
    let cover = manifest
        .pointer("/documents/cover_letter")
        .context("ccvl.json has no cover-letter contract")?;
    ensure!(
        cover.pointer("/body_lines") == Some(&json!({"minimum": 25, "target": 28, "maximum": 28})),
        "ccvl.json: cover-letter body contract changed"
    );
    ensure!(
        cover.pointer("/highlights/count") == Some(&Value::from(5)),
        "ccvl.json: cover letter needs exactly five highlights"
    );
    ensure!(
        cover.pointer("/widow_or_orphan_lines") == Some(&Value::from(0)),
        "ccvl.json: widow/orphan rule changed"
    );
    Ok(())
}

fn validate_embedded_fonts(workspace: &Workspace) -> Result<()> {
    ensure!(
        ctypst::fonts::documents().len() == 16,
        "the Rust binary must embed all 16 declared fonts"
    );
    let expected = [
        "Archivo-Bold.ttf",
        "Archivo-Italic.ttf",
        "Archivo-Medium.ttf",
        "Archivo-Regular.ttf",
    ];
    for name in expected {
        let bytes = fs::read(workspace.path(format!("cvl/shared/fonts/{name}")))?;
        ensure!(
            matches!(
                bytes.get(..4),
                Some(b"\x00\x01\x00\x00" | b"OTTO" | b"true" | b"typ1")
            ),
            "bundled font is missing or invalid: {name}"
        );
    }
    Ok(())
}

fn render_and_verify(workspace: &Workspace) -> Result<()> {
    let profile = workspace.read_json("cvl/general/profile.json")?;
    let contacts = ["name", "email", "phone_label"]
        .into_iter()
        .map(|field| {
            profile
                .get(field)
                .and_then(Value::as_str)
                .with_context(|| format!("profile has no {field}"))
                .map(str::to_owned)
        })
        .collect::<Result<Vec<_>>>()?;
    let temporary = TempDir::new()?;
    let first = temporary.path().join("first");
    let second = temporary.path().join("second");
    let compiler = Compiler::new(workspace)?;
    for locale in ["de-ch", "en-ch"] {
        let mut verified = Vec::new();
        for pages in [2, 3, 4] {
            let mut one = general_cv_spec(workspace, locale, pages)?;
            one.output = first.join(format!("cv-{locale}-{pages}.pdf"));
            let mut two = one.clone();
            two.output = second.join(format!("cv-{locale}-{pages}.pdf"));
            compiler.render(workspace, &one)?;
            compiler.render(workspace, &two)?;
            ensure!(
                fs::read(&one.output)? == fs::read(&two.output)?,
                "CV build is not byte-reproducible: {locale} {pages} pages"
            );
            let tracked = workspace.path(format!("cvl/cv/output/{locale}/{pages}pager/cv.pdf"));
            ensure!(
                fs::read(&one.output)? == fs::read(&tracked)?,
                "tracked CV output is stale or platform-dependent: {locale} {pages} pages"
            );
            verified.push(pdf::verify(&one.output, pages, &contacts, false)?);
        }
        for page in [1, 2] {
            let baseline = verified[0].page_content(page)?;
            ensure!(
                verified[1].page_content(page)? == baseline
                    && verified[2].page_content(page)? == baseline,
                "shared CV page changed across presets: {locale} page {page}"
            );
        }
        let mut one = general_cl_spec(workspace, locale)?;
        one.output = first.join(format!("cl-{locale}.pdf"));
        let mut two = one.clone();
        two.output = second.join(format!("cl-{locale}.pdf"));
        compiler.render(workspace, &one)?;
        compiler.render(workspace, &two)?;
        ensure!(
            fs::read(&one.output)? == fs::read(&two.output)?,
            "cover-letter build is not byte-reproducible: {locale}"
        );
        let tracked = workspace.path(format!("cvl/cl/output/{locale}/cl.pdf"));
        ensure!(
            fs::read(&one.output)? == fs::read(&tracked)?,
            "tracked cover-letter output is stale or platform-dependent: {locale}"
        );
        pdf::verify(&one.output, 1, &contacts, true)?;
    }
    Ok(())
}

pub fn check_one_pdf(workspace: &Workspace, spec: &DocumentSpec) -> Result<()> {
    let compiler = Compiler::new(workspace)?;
    compiler.render(workspace, spec)?;
    let profile = workspace.read_json("cvl/general/profile.json")?;
    let contacts = ["name", "email", "phone_label"]
        .into_iter()
        .filter_map(|key| profile.get(key).and_then(Value::as_str).map(str::to_owned))
        .collect::<Vec<_>>();
    pdf::verify(
        &spec.output,
        spec.expected_pages,
        &contacts,
        spec.expected_pages == 1,
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn checked_in_manifest_has_fixed_contract() {
        let workspace = Workspace::discover(None).unwrap();
        validate_manifest(&workspace).unwrap();
    }
}
