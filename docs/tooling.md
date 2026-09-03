# Tooling

ccvl uses a small command-line toolchain:

| Tool | Required for |
|---|---|
| Typst | compiling document sources |
| Just | optional shorthand for repository commands |
| Poppler (`pdfinfo`, `pdftotext`, `pdftoppm`) | page, ATS, and visual checks |
| QPDF | independent PDF structure validation |
| ripgrep | publication and repository checks |
| Typstyle | deterministic Typst formatting |

Run `bash ./ccvl bootstrap` for a read-only setup plan. `bash ./ccvl setup` installs
missing host dependencies through the detected package manager, keeps pinned
document binaries in `.cache/ccvl/bin`, and runs the complete check. It supports
Linux x86_64/aarch64 and macOS x86_64/arm64; Windows users should use WSL.

An experienced user may install the listed tools independently and run
`bash ./ccvl doctor` plus `bash ./ccvl check`. Existing working global tools are not
replaced; the repository-local path only takes precedence while `./ccvl` runs.

## Bundled fonts

Archivo is included directly in the repository, including source archives. Use
`bash ./ccvl build`, the more specific `just` recipes, or `just watch-cv`. These
commands always pass `--font-path cvl/shared/fonts` and disable system-font
discovery, so the same font files are used on every machine.

A raw Typst invocation needs the equivalent flags explicitly:

```sh
typst compile --root . --font-path cvl/shared/fonts --ignore-system-fonts SOURCE.typ OUTPUT.pdf
```

Without `--font-path`, Typst cannot discover a repository-local font and may
render a fallback while only emitting a warning. `bash ./ccvl check` treats any Typst
diagnostic or non-Archivo PDF font as a failure. The workspace's Tinymist
settings configure the same bundled path for editor previews.

Do not widen permissions, enable package lifecycle scripts, add hidden hooks,
or weaken `.gitignore` as part of setup.
