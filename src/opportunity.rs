use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result, bail};
use regex::Regex;

use crate::workspace::{Workspace, read_json};

pub fn record_path(
    workspace: &Workspace,
    organisation: &str,
    position: &str,
    require_exists: bool,
) -> Result<PathBuf> {
    let pattern = Regex::new(r"^[a-z0-9]+(?:[-_][a-z0-9]+)*$")?;
    for (label, value) in [("organisation", organisation), ("position", position)] {
        if !pattern.is_match(value) {
            bail!("invalid {label} key: {value:?}");
        }
    }
    let record = workspace.path(format!(
        "opportunities/{organisation}/{position}/application.json"
    ));
    if require_exists && !record.is_file() {
        bail!(
            "opportunity record does not exist: opportunities/{organisation}/{position}/application.json"
        );
    }
    Ok(record)
}

pub fn create_record(workspace: &Workspace, organisation: &str, position: &str) -> Result<PathBuf> {
    let destination = record_path(workspace, organisation, position, false)?;
    if destination.exists() {
        bail!(
            "refusing to overwrite existing opportunity: {}",
            workspace.relative(&destination)?.display()
        );
    }
    let mut document = read_json(&workspace.path("templates/application.json"))?;
    document["job"]["id"] = format!("{organisation}--{position}").into();
    let parent = destination
        .parent()
        .context("opportunity path has no parent")?;
    fs::create_dir_all(parent)?;
    fs::write(
        &destination,
        format!("{}\n", serde_json::to_string_pretty(&document)?),
    )?;
    Ok(destination)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn path_keys_cannot_escape() {
        let workspace = Workspace::discover(None).unwrap();
        assert!(record_path(&workspace, "../acme", "lead", false).is_err());
        assert!(record_path(&workspace, "ACME", "lead", false).is_err());
    }
}
