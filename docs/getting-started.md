# Getting started

You can use ccvl without knowing Git, Typst, Python, or package managers. You
need a folder that a coding agent can read and a terminal it can use. Native
Linux x86_64/aarch64, macOS Intel/Apple Silicon, and Windows x86_64/ARM64 are
supported.

## With a coding agent

[Download and extract the source
archive](https://github.com/corbet-labs/ccvl/archive/refs/heads/main.zip), open
the extracted folder in Codex or another filesystem-capable coding agent, and
use this prompt:

> Set up this ccvl workspace. Read AGENTS.md, use the ccvl-install skill and the
> checked-in platform dispatcher, verify the complete showcase, then help me
> build my own evidence-backed profile. Ask me about facts, not tooling, unless
> the harness reaches an unavoidable system-permission decision.

The agent should first run `bash ./ccvl bootstrap` on Linux/macOS or
`.\ccvl.cmd bootstrap` on Windows. That command is read-only and shows the exact
plan. Because the prompt explicitly requests setup, it may then run the matching
`setup` command. Setup:

- detects empty, partial, and already complete environments on the current OS;
- reuses exact matching Typst, Typstyle, and uv versions when present, or
  downloads pinned native releases into `.cache/ccvl/bin` and verifies their
  published SHA-256 digests;
- uses uv to install the pinned Python runtime and hash-locked PDF dependency
  below `.cache/ccvl/`, leaving global versions untouched;
- installs only a missing downloader or XZ support on minimal Linux; native
  Windows and macOS need no package-manager bootstrap;
- runs the full deterministic suite before declaring success.

Re-running setup is safe. If the correct tools are already present, it makes no
changes and performs the same verification.

## From a terminal

No Git is required. In the extracted folder on Linux or macOS:

```sh
bash ./ccvl bootstrap
bash ./ccvl setup
```

On Windows, use Command Prompt or PowerShell:

```powershell
.\ccvl.cmd bootstrap
.\ccvl.cmd setup
```

`bootstrap` only reports. `setup` is the explicit instruction to install what
the report identifies. For an already managed environment, install the listed
dependencies however you prefer and run:

```sh
bash ./ccvl doctor
bash ./ccvl check
```

All product commands are available through `bash ./ccvl help` or
`.\ccvl.cmd help`. The `justfile` is a POSIX convenience layer for users who
already use Just; it is not needed to begin.

## What happens next

Start with `ccvl-profile`. It builds a private, source-linked fact base before
the public showcase is replaced. The agent must never reuse the showcase
author's claims or wording as yours: they are reference-only personal content,
not a template. It must ask rather than fill an evidence gap with a plausible
statement.
