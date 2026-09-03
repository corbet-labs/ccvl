---
name: ccvl-install
description: Prepare or repair a ccvl authoring environment when Typst, PDF tooling, Git LFS, formatting, or repository checks are missing.
---

# Install ccvl tooling

Establish the smallest working toolchain for the current host and prove it by
rendering the checked-in showcase.

## Workflow

1. Run `just doctor` from the repository root. If Just itself is absent, run
   `scripts/doctor.sh` directly.
2. Identify only the missing commands and the host's established package
   manager. Do not replace an already working toolchain.
3. Show the exact installation command and its affected packages before a
   privileged or host-wide change. If the user already explicitly requested
   installation, execute the smallest suitable command.
4. Never widen filesystem permissions, enable package lifecycle scripts, add a
   hidden hook, or weaken `.gitignore` to make setup pass.
5. Run `git lfs pull`, `just doctor`, and `just check` after installation.

The required tools and their roles are listed in
`../../../docs/tooling.md`. Prefer native packages on supported hosts. Do not
introduce containers or an application database for this file-native product.
