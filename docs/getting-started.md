# Getting started

You can use ccvl without knowing Git, Typst, or package managers. You need a
Linux or macOS folder that a coding agent can read and a terminal it can use.
On Windows, use WSL. Native Windows support is not claimed yet.

## With a coding agent

[Download and extract the source
archive](https://github.com/corbet-labs/ccvl/archive/refs/heads/main.zip), open
the extracted folder in Codex or another filesystem-capable coding agent, and
use this prompt:

> Set up this ccvl workspace. Read AGENTS.md, use the ccvl-install skill and the
> checked-in harness, verify the complete showcase, then help me build my own
> evidence-backed profile. Ask me about facts, not tooling, unless the harness
> reaches an unavoidable system-permission decision.

The agent should run `bash ./ccvl bootstrap` first. That command is read-only and
shows the exact plan. Because the prompt explicitly requests setup, it may then
run `bash ./ccvl setup`. The setup command:

- detects empty, partial, and already complete environments;
- installs only missing host packages through the detected package manager;
- downloads pinned Typst, Typstyle, and Just releases into
  `.cache/ccvl/bin`, verifies their SHA-256 checksums, and leaves global versions
  untouched;
- runs the full deterministic suite before declaring success.

Re-running setup is safe. If the correct tools are already present, it makes no
changes and performs the same verification.

## From a terminal

No Git is required. In the extracted folder:

```sh
bash ./ccvl bootstrap
bash ./ccvl setup
```

`bootstrap` only reports. `setup` is the explicit instruction to install what
the report identifies. For an already managed environment, install the listed
dependencies however you prefer and run:

```sh
bash ./ccvl doctor
bash ./ccvl check
```

All product commands are available through `bash ./ccvl help`. The `justfile` is a
convenience layer for users who already use Just; it is not needed to begin.

## What happens next

Start with `ccvl-profile`. It builds a private, source-linked fact base before
the public showcase is replaced. The agent must never reuse the showcase
author's claims as yours, and it must ask rather than fill an evidence gap with
a plausible statement.
