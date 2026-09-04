use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};
use serde_json::Value;

#[derive(Clone, Debug)]
pub struct Workspace {
    root: PathBuf,
}

impl Workspace {
    pub fn discover(explicit: Option<&Path>) -> Result<Self> {
        if let Some(root) = explicit {
            return Self::at(root);
        }
        if let Ok(cwd) = std::env::current_dir()
            && let Some(root) = find_root(&cwd)
        {
            return Self::at(&root);
        }
        if let Ok(executable) = std::env::current_exe()
            && let Some(parent) = executable.parent()
            && let Some(root) = find_root(parent)
        {
            return Self::at(&root);
        }
        bail!("no ccvl.json found in the current directory or its parents")
    }

    pub fn at(root: &Path) -> Result<Self> {
        let root = root
            .canonicalize()
            .with_context(|| format!("cannot resolve workspace {}", root.display()))?;
        if !root.join("ccvl.json").is_file() {
            bail!("{} is not a ccvl workspace", root.display());
        }
        Ok(Self { root })
    }

    #[must_use]
    pub fn root(&self) -> &Path {
        &self.root
    }

    #[must_use]
    pub fn path(&self, relative: impl AsRef<Path>) -> PathBuf {
        self.root.join(relative)
    }

    pub fn existing_inside(&self, value: impl AsRef<Path>) -> Result<PathBuf> {
        let value = value.as_ref();
        let candidate = if value.is_absolute() {
            value.to_path_buf()
        } else {
            self.root.join(value)
        };
        let resolved = candidate
            .canonicalize()
            .with_context(|| format!("cannot resolve {}", value.display()))?;
        if !resolved.starts_with(&self.root) {
            bail!(
                "input must be inside the ccvl workspace: {}",
                value.display()
            );
        }
        Ok(resolved)
    }

    pub fn relative(&self, path: &Path) -> Result<PathBuf> {
        path.strip_prefix(&self.root)
            .map(Path::to_path_buf)
            .with_context(|| format!("{} is outside the ccvl workspace", path.display()))
    }

    pub fn typst_path(&self, path: &Path) -> Result<String> {
        let relative = self.relative(&self.existing_inside(path)?)?;
        Ok(format!(
            "/{}",
            relative.to_string_lossy().replace('\\', "/")
        ))
    }

    pub fn read_json(&self, relative: impl AsRef<Path>) -> Result<Value> {
        read_json(&self.path(relative))
    }
}

pub fn read_json(path: &Path) -> Result<Value> {
    let text = fs::read_to_string(path)
        .with_context(|| format!("cannot read JSON file {}", path.display()))?;
    serde_json::from_str(&text).with_context(|| format!("invalid JSON in {}", path.display()))
}

fn find_root(start: &Path) -> Option<PathBuf> {
    start
        .ancestors()
        .find(|candidate| candidate.join("ccvl.json").is_file())
        .map(Path::to_path_buf)
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    fn repository() -> Workspace {
        Workspace::at(Path::new(env!("CARGO_MANIFEST_DIR"))).unwrap()
    }

    #[test]
    fn repository_root_is_discoverable() {
        let workspace = Workspace::discover(None).unwrap();
        assert!(workspace.root().join("ccvl.json").is_file());
    }

    #[test]
    fn parent_escape_is_rejected() {
        let workspace = repository();
        assert!(workspace.existing_inside("../applications").is_err());
    }

    #[test]
    fn three_working_groups_are_top_level_and_documented() {
        let workspace = repository();
        for name in ["cvl", "targets", "opportunities"] {
            assert!(workspace.path(name).is_dir());
            assert!(workspace.path(name).join("README.md").is_file());
        }
    }

    #[test]
    fn manifest_names_the_general_and_keyed_opportunity_contracts() {
        let repository = repository();
        let manifest_text = fs::read_to_string(repository.path("ccvl.json")).unwrap();
        let workspace_groups = manifest_text.split_once("\"workspace_groups\"").unwrap().1;
        let cvl = workspace_groups.find("\"cvl\"").unwrap();
        let targets = workspace_groups.find("\"targets\"").unwrap();
        let opportunities = workspace_groups.find("\"opportunities\"").unwrap();
        assert!(cvl < targets && targets < opportunities);

        let manifest: Value = serde_json::from_str(&manifest_text).unwrap();
        let groups = manifest["workspace_groups"].as_object().unwrap();
        assert_eq!(groups["cvl"]["profile"], "cvl/general/profile.json");
        assert_eq!(groups["cvl"]["stations"], "cvl/general/stations.json");
        assert_eq!(
            groups["opportunities"]["path"],
            "opportunities/<organisation-key>/<position-key>"
        );
        assert_eq!(groups["opportunities"]["record"], "application.json");
        assert_eq!(groups["opportunities"]["output"], "output");
    }

    #[test]
    fn cv_preset_directories_use_spelled_out_names_only() {
        let workspace = repository();
        let expected = std::collections::BTreeSet::from([
            "fourpager".to_owned(),
            "threepager".to_owned(),
            "twopager".to_owned(),
        ]);
        for locale in ["de-ch", "en-ch"] {
            let root = workspace.path(format!("cvl/cv/output/{locale}"));
            let actual = fs::read_dir(&root)
                .unwrap()
                .filter_map(std::result::Result::ok)
                .filter(|entry| entry.path().is_dir())
                .map(|entry| entry.file_name().to_string_lossy().into_owned())
                .collect::<std::collections::BTreeSet<_>>();
            assert_eq!(actual, expected);
            for preset in &expected {
                assert!(root.join(preset).join("cv.pdf").is_file());
            }
        }
    }

    #[test]
    fn editor_previews_use_only_bundled_fonts() {
        let workspace = repository();
        let vscode = workspace.read_json(".vscode/settings.json").unwrap();
        let zed = workspace.read_json(".zed/settings.json").unwrap();
        assert_eq!(
            vscode["tinymist.fontPaths"],
            json!(["${workspaceFolder}/cvl/shared/fonts"])
        );
        assert_eq!(vscode["tinymist.systemFonts"], false);
        assert_eq!(
            zed["lsp"]["tinymist"]["settings"]["fontPaths"],
            json!(["cvl/shared/fonts"])
        );
        assert_eq!(zed["lsp"]["tinymist"]["settings"]["systemFonts"], false);
    }

    #[test]
    fn private_downstream_sync_is_push_driven_and_gated() {
        let workflow =
            fs::read_to_string(repository().path(".crow/private-downstream.yaml")).unwrap();
        assert!(workflow.contains("event: push"));
        assert!(workflow.contains("branch: main"));
        assert!(!workflow.contains("event: cron"));
        assert!(!workflow.contains("event: manual"));
        assert!(workflow.contains("CARGO_TARGET_DIR: /caches/cargo/targets/ccvl"));
        assert!(workflow.contains("cargo build --locked"));
        assert!(!workflow.contains("cargo build --locked --release"));
        assert!(workflow.contains("downstream-check"));
        let push = workflow.find("git push --porcelain").unwrap();
        assert!(workflow.find("downstream-check").unwrap() < push);
        assert!(workflow.find("\"$gate\" check").unwrap() < push);
    }
}
