# Cover-letter project

The public DE-CH and EN-CH documents are a hybrid open application and ccvl
demonstration. They consume the same versioned `application.json` shape used
for concrete opportunities.

Every letter renders exactly six paragraphs and five one-line highlights.
Paragraph 1 uses three lines; paragraphs 2–5 share 20–22 lines; paragraph 6
uses two or three lines. Build the general letter with `just build-cl <locale>`.
Build a keyed opportunity through `ccvl build-opportunity`, as documented in
`docs/applications.md`.

The bundled signature is synthetic and was generated specifically for this
public demo. It is not a scan or reconstruction of a handwritten signature.
