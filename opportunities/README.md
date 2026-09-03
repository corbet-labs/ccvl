# Opportunities

Every concrete role lives directly under a stable two-part key:

```text
opportunities/<organisation-key>/<position-key>/
├── application.json
├── posting.md                 optional archived source
├── interview-<stage>.md       optional preparation
├── outcome.md                 optional observed outcome
└── output/
    ├── cv.pdf
    └── cl.pdf                 only when the cover letter is enabled
```

Both keys use lowercase ASCII letters, numbers, hyphens, or underscores. The
single `application.json` owns the selected CV page count, five tailored
Summary lines, optional six-paragraph cover letter, and five highlights. Its
directory is the key; do not add generic `companies/`, `positions/`,
`applications/`, or `out/` layers.

Create the record deterministically, then ask the `ccvl-apply` skill to
research, draft, review, measure, and render it:

```sh
bash ./ccvl new-opportunity <organisation-key> <position-key>
bash ./ccvl build-opportunity <organisation-key> <position-key>
```

The public ccvl repository intentionally contains only this scaffold. Real
postings, recipient details, tailored documents, and outcomes belong in a
private downstream.
