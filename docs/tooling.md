# Tooling

ccvl uses a small command-line toolchain:

| Tool | Required for |
|---|---|
| Typst | compiling document sources |
| Typstyle | deterministic Typst formatting |
| uv | pinned Python and locked dependency environment |
| Python + pypdf | schemas, PDF structure, ATS text, fonts, and reproducibility |
| Just | optional POSIX shorthand for repository commands |
| Poppler + QPDF | secondary Linux CI validation |

Run `bash ./ccvl bootstrap` on Linux/macOS or `.\ccvl.cmd bootstrap` on Windows
for a read-only setup plan. The matching `setup` command keeps native binaries,
Python 3.13.15, and hash-locked dependencies below `.cache/ccvl/`, then runs the
complete check. It supports Linux and macOS on x86_64/aarch64 plus native
Windows on x86_64/ARM64.

An experienced user may install matching tools independently and run the
platform `doctor` plus `check` commands. Matching global tools are reused;
otherwise the repository-local path takes precedence only while ccvl runs.

## Bundled fonts

Archivo is included directly in the repository, including source archives. Use
`bash ./ccvl build` or `.\ccvl.cmd build`. These commands always pass
`--font-path cvl/shared/fonts` and disable system-font discovery, so the same
font files are used on every machine.

A raw Typst invocation needs the equivalent flags explicitly:

```sh
typst compile --root . --font-path cvl/shared/fonts --ignore-system-fonts SOURCE.typ OUTPUT.pdf
```

Without `--font-path`, Typst cannot discover a repository-local font and may
render a fallback while only emitting a warning. The platform `check` command
treats any Typst diagnostic or non-Archivo PDF font as a failure. The workspace's Tinymist
settings configure the same bundled path for editor previews.

Do not widen permissions, enable package lifecycle scripts, add hidden hooks,
or weaken `.gitignore` as part of setup.
