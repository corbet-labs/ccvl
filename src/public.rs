use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail, ensure};
use regex::Regex;
use unicode_normalization::UnicodeNormalization;
use walkdir::WalkDir;

use crate::workspace::Workspace;

const EXCLUDED_ROOTS: &[&str] = &[
    ".cache",
    ".git",
    "applications",
    "evidence",
    "out",
    "outcomes",
    "private",
    "sources",
    "submissions",
    "target",
    "tmp",
];

pub fn public_files(workspace: &Workspace) -> Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    for entry in WalkDir::new(workspace.root()).follow_links(false) {
        let entry = entry?;
        if !entry.file_type().is_file() {
            continue;
        }
        let relative = workspace.relative(entry.path())?;
        if relative.components().count() == 1
            && relative
                .file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.nfc().eq("Schwächen.md".nfc()))
        {
            continue;
        }
        if relative.components().next().is_some_and(|part| {
            EXCLUDED_ROOTS
                .iter()
                .any(|excluded| part.as_os_str() == *excluded)
        }) || relative
            .components()
            .any(|part| part.as_os_str() == "__pycache__")
        {
            continue;
        }
        files.push(entry.into_path());
    }
    files.sort();
    Ok(files)
}

pub fn validate_repository(workspace: &Workspace) -> Result<()> {
    validate_markdown_links(workspace)?;
    validate_text_files(workspace)
}

pub fn validate_boundary(workspace: &Workspace) -> Result<()> {
    for root in [
        "applications",
        "evidence",
        "out",
        "outcomes",
        "private",
        "sources",
        "submissions",
    ] {
        ensure!(
            !workspace.path(root).exists(),
            "private downstream path exists: {root}"
        );
    }
    let allowed = BTreeSet::from([
        PathBuf::from("cvl/evidence/README.md"),
        PathBuf::from("cvl/imports/README.md"),
        PathBuf::from("opportunities/README.md"),
        PathBuf::from("targets/README.md"),
    ]);
    for path in public_files(workspace)? {
        let relative = workspace.relative(&path)?;
        let in_workspace_data = relative.components().next().is_some_and(|part| {
            part.as_os_str() == "opportunities" || part.as_os_str() == "targets"
        }) || relative.starts_with("cvl/evidence")
            || relative.starts_with("cvl/imports");
        ensure!(
            !in_workspace_data || allowed.contains(&relative),
            "public workspace contains private evidence, import, target, or opportunity data: {}",
            relative.display()
        );
    }
    for entry in WalkDir::new(workspace.root()).follow_links(false) {
        let entry = entry?;
        let relative = workspace.relative(entry.path())?;
        if relative.starts_with(".git")
            || relative.starts_with(".cache")
            || relative.starts_with("target")
        {
            continue;
        }
        ensure!(
            !entry.path_is_symlink(),
            "symlink requires manual publication review: {}",
            relative.display()
        );
    }
    for entry in WalkDir::new(workspace.path("cvl")) {
        let entry = entry?;
        if entry.file_type().is_file() {
            let bytes = fs::read(entry.path())?;
            ensure!(
                !bytes.starts_with(b"version https://git-lfs.github.com/spec/v1"),
                "unresolved Git LFS pointer: {}",
                workspace.relative(entry.path())?.display()
            );
        }
    }
    let secret = Regex::new(
        r"(?m)-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}",
    )?;
    let private = Regex::new(concat!(
        r"/home/",
        "richc",
        r"|julian-corbet/",
        "applications",
        r"|BEGIN OPENSSH ",
        "PRIVATE KEY"
    ))?;
    for path in public_files(workspace)? {
        let relative = workspace.relative(&path)?;
        let is_font = relative.starts_with("cvl/shared/fonts");
        let is_output = relative.extension().is_some_and(|ext| ext == "pdf")
            && relative
                .components()
                .any(|part| part.as_os_str() == "output");
        if relative != Path::new("cvl/cl/assets/signature.png") && !is_font && !is_output {
            let text = String::from_utf8_lossy(&fs::read(&path)?).into_owned();
            ensure!(
                !secret.is_match(&text),
                "potential secret found: {}",
                relative.display()
            );
            let declares_public_identifiers = relative == Path::new("PUBLIC_IDENTIFIERS.md")
                || relative == Path::new("scripts/public_check.py");
            if !declares_public_identifiers {
                ensure!(
                    !private.is_match(&text),
                    "private workspace identifier found: {}",
                    relative.display()
                );
            }
        }
    }
    Ok(())
}

fn validate_markdown_links(workspace: &Workspace) -> Result<()> {
    let link = Regex::new(r"!?\[[^]]*\]\(([^)]+)\)")?;
    let mut errors = Vec::new();
    for path in public_files(workspace)?
        .into_iter()
        .filter(|path| path.extension().is_some_and(|ext| ext == "md"))
    {
        let text = fs::read_to_string(&path)?;
        for captures in link.captures_iter(&text) {
            let mut destination = captures[1].trim().to_owned();
            if destination.starts_with('<') && destination.contains('>') {
                destination = destination[1..destination.find('>').expect("checked")].to_owned();
            } else {
                destination = destination
                    .split_whitespace()
                    .next()
                    .unwrap_or_default()
                    .to_owned();
            }
            if destination.is_empty()
                || ["#", "http://", "https://", "mailto:"]
                    .iter()
                    .any(|prefix| destination.starts_with(prefix))
            {
                continue;
            }
            let clean = destination
                .split(['#', '?'])
                .next()
                .unwrap_or_default()
                .replace("%20", " ");
            let candidate = if clean.starts_with('/') {
                workspace.path(clean.trim_start_matches('/'))
            } else {
                path.parent()
                    .context("Markdown file has no parent")?
                    .join(clean)
            };
            if !candidate.exists() {
                errors.push(format!(
                    "{} -> {destination}",
                    workspace.relative(&path)?.display()
                ));
            }
        }
    }
    if !errors.is_empty() {
        bail!("broken local Markdown links: {}", errors.join(", "));
    }
    Ok(())
}

fn validate_text_files(workspace: &Workspace) -> Result<()> {
    let suffixes = [
        "cmd", "csv", "json", "lock", "md", "ps1", "rs", "sh", "toml", "typ", "yaml", "yml",
    ];
    let names = [".gitattributes", ".gitignore", "ccvl", "justfile"];
    let trailing = Regex::new(r"(?m)[ \t]+$")?;
    let merge = Regex::new(r"(?m)^(<{7}|={7}|>{7})(?: |$)")?;
    let mut errors = Vec::new();
    for path in public_files(workspace)? {
        let relative = workspace.relative(&path)?;
        let textual = relative
            .extension()
            .and_then(|item| item.to_str())
            .is_some_and(|ext| suffixes.contains(&ext))
            || relative
                .file_name()
                .and_then(|item| item.to_str())
                .is_some_and(|name| names.contains(&name));
        if !textual {
            continue;
        }
        let bytes = fs::read(&path)?;
        let Ok(text) = String::from_utf8(bytes) else {
            errors.push(format!("{}: not valid UTF-8", relative.display()));
            continue;
        };
        if !text.is_empty() && !text.ends_with('\n') {
            errors.push(format!("{}: missing final newline", relative.display()));
        }
        if text.contains('\r') {
            errors.push(format!("{}: contains CR line endings", relative.display()));
        }
        if trailing.is_match(&text) {
            errors.push(format!("{}: trailing whitespace", relative.display()));
        }
        if merge.is_match(&text) {
            errors.push(format!("{}: unresolved merge marker", relative.display()));
        }
    }
    if !errors.is_empty() {
        bail!("text hygiene failures: {}", errors.join(", "));
    }
    Ok(())
}
