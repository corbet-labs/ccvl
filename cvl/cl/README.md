# Cover-letter project

The public DE-CH and EN-CH documents are a hybrid open application and ccvl
demonstration. They consume a CareerVector-aligned `application.json`
shape used for concrete opportunities, with ccvl's explicit letter-date
extension. CareerVector import is a planned, reviewed transition rather than a
claim that current versions already ingest a ccvl workspace.

Every letter renders exactly five paragraphs and five highlights. Build the
showcase with `just build-cl <locale>`. Build a private opportunity by passing
its application file through the repository command documented in
`docs/applications.md`.

The bundled signature is synthetic and was generated specifically for this
public demo. It is not a scan or reconstruction of a handwritten signature.
