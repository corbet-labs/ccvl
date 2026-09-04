# General CV and cover letter

This directory contains the approved, renderable general document. It is a
projection of verified user evidence, not the evidence store itself.

```text
cvl/
├── profile.json
├── assets/
├── de-ch/
│   ├── application.json
│   ├── cv.typ
│   ├── cl.typ
│   └── output/{cv-2.pdf,cv-3.pdf,cv-4.pdf,cl.pdf}
└── en-ch/
    └── ...
```

`profile.json` contains only approved fields used in the rendered header. Each
locale's `application.json` provides the general five-line Summary and cover
letter. Shared rendering code, fonts, schemas, and neutral scaffolds belong in
`.agent/`; source documents, the rich profile, journal, and station allocation
belong in `interview/`.

A keyed opportunity supplies its own `application.json` from
`../opportunities/<organisation>/<position>/` while reusing this general CV
body and render profile.

The CV has a fixed layout: 6–8 full experience entries on page 1, exactly 10
two-bullet supporting entries on page 2, exactly 10 two-bullet projects on page
3, and three groups of three three-line competency blocks on page 4. Run
`bash ./ccvl profile-status --verify-sources` before rendering.
