---
name: ccvl-install
description: Prepare or repair a ccvl authoring environment when Typst, PDF tooling, formatting, or repository checks are missing.
---

# Install ccvl tooling

Establish the smallest working toolchain for the current host and prove it by
rendering the checked-in general CVL.

## Workflow

1. Detect the host. Run `bash ./ccvl bootstrap` on Linux/macOS or
   `.\ccvl.cmd bootstrap` on native Windows. Do not improvise a parallel
   installer, require Git knowledge, or route Windows users through WSL.
2. If it reports no tool changes, run the matching platform `check` command and
   stop changing the environment.
3. If the user explicitly requested setup or installation, run the matching
   platform `setup` command. Otherwise show the plan before its changes.
4. If the harness cannot support the platform, report its exact boundary and
   use `../../../docs/tooling.md`; do not guess package names.
5. Do not replace an existing package strategy or working global toolchain.
   Pinned native tools, Python, and locked dependencies belong in the
   repository-local cache.
6. Never widen filesystem permissions, enable package lifecycle scripts, add a
   hidden hook, or weaken `.gitignore` to make setup pass.
7. Confirm that the bundled Archivo files are real fonts and that the supported
   render path discovers all four variants.
8. Require the full setup check before starting profile or document edits.

Use the repository commands for rendering. A raw `typst compile` does not
discover repository-local fonts by itself; it must receive both
`--font-path cvl/shared/fonts` and `--ignore-system-fonts`. The checked-in
Tinymist settings provide the same font path for editor previews.

The required tools and their roles are listed in `../../../docs/tooling.md`.
The SHA-256-pinned asset matrix is authoritative for all six supported
OS/architecture pairs. Prefer the non-privileged, repository-local bootstrap;
use a native package manager only for a missing downloader or archive utility
it cannot provide. Do not introduce containers or an application database for
this file-native product.
