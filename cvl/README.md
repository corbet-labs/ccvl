# Document suite

The suite contains the bilingual CV and cover-letter showcase plus their shared
Typst presentation layer.

- `cv/`: exact two-, three-, and four-page CV presets;
- `cl/`: one-page cover letters with five paragraphs, 14–16 body lines, and
  five near-centred highlights;
- `shared/`: profile, validation, measured line contracts, layout, components,
  and bundled fonts.

Both document types consume a versioned `application.json`. The public default
is selected from `showcase/<locale>/application.json`; private downstreams pass
an opportunity-specific file instead.
