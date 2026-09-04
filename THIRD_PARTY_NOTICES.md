# Third-party notices

ccvl bundles Archivo, EB Garamond, IBM Plex Serif, and Source Serif 4 font
files. They are separate works distributed under the SIL Open Font License 1.1.
Detailed copyright and reserved-font-name notices are in
`cvl/shared/fonts/NOTICE.md`; the license text is available in both
`cvl/shared/fonts/OFL-1.1.txt` and `LICENSES/OFL-1.1.txt`.

The native ccvl binary links the Typst and Typstyle engines from locked Rust
dependencies and embeds the bundled font files. Rust and Cargo are required to
build that binary. Just, Poppler, QPDF, Git, curl, and ripgrep are external tools
and are not redistributed by this repository. The bootstrap installs the exact
Rust toolchain only after the user requests setup, then builds ccvl from the
frozen `Cargo.lock` dependency graph.
