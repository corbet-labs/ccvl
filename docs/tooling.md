# Tooling

ccvl uses a small command-line toolchain:

| Tool | Required for |
|---|---|
| Typst | compiling document sources |
| Just | stable repository commands |
| Poppler (`pdfinfo`, `pdftotext`, `pdftoppm`) | page, ATS, and visual checks |
| Git LFS | bundled fonts and generated PDFs |
| ripgrep | publication and repository checks |
| Typstyle | deterministic Typst formatting |

Run `just doctor` to report what is present. The `ccvl-install` skill may install
missing tools only after the user authorises that host change. It should prefer
the host's established package manager and verify the installed commands with
`just doctor` and `just check`.

Do not widen permissions, enable package lifecycle scripts, add hidden hooks,
or weaken `.gitignore` as part of setup.
