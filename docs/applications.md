# One file per opportunity

Every concrete opportunity has exactly one canonical tailored-data file:

```text
applications/<job-id>/application.json
```

Create it from `templates/application.json`. The shape intentionally follows
CareerVector TUI's application schema:

- `job`: vacancy, organisation, source, description, context, notes, and
  recipient;
- `tailored_cv.summary`: the Summary inserted into the CV;
- `tailored_cl.paragraphs`: exactly five cover-letter paragraphs;
- `tailored_cl.highlights`: exactly five highlight lines;
- `constraints`: rendered line limits for all tailored fields.

An archived posting, research notes, or correspondence may sit beside the JSON
file, but must not duplicate its tailored fields. This makes the future
CareerVector TUI importer deterministic and prevents Markdown and rendered
documents from becoming competing sources of truth.

`application_date` is a ccvl field reserved for the rendered letter. The
CareerVector importer must preserve it when support lands rather than silently
discarding it.

Render one private application from the repository root:

```sh
bash ./ccvl build-application applications/<job-id>/application.json de-ch 4
```

The command validates the application while rendering and writes `cv.pdf` and
`cl.pdf` below the ignored `out/<job-id>/` directory. Use `en-ch` for an
English application and select the two-, three-, or four-page CV preset with
the final argument.
