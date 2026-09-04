# One keyed package per opportunity

Every concrete opportunity has one canonical tailored-data file:

```text
opportunities/<organisation-key>/<position-key>/application.toml
```

The general CV foundation must first pass `ccvl profile-status
--verify-sources`. Tailoring cannot repair a core page that lacks enough
verified stations.

Create it without choosing or copying paths manually:

```sh
bash ./ccvl new-opportunity <organisation-key> <position-key>
```

The command validates both keys, copies
`.agent/scaffolds/opportunity/application.toml`, assigns a stable ID, and
refuses to overwrite an existing record. Schema version 4
contains:

- `options`: language, CV page count, cover-letter switch, application date;
- `job`: vacancy, organisation, source, description, context, notes, and
  recipient;
- `cv.summary`: one flowing paragraph that must typeset to exactly five
  lines;
- when the cover letter is enabled, exactly six paragraphs following
  `.agent/docs/cover-letter.md` and exactly five one-line highlights.

Line lengths are authored as plain text; fill defaults come from `ccvl.json`.
Typst measures actual glyph width with the bundled font. Underfill and
overflow fail and prompt another evidence-backed rewrite.

The opportunity directory is the lifecycle unit. An archived posting,
research, working rules, interview preparation, or outcome may sit beside the
TOML file. Summary and cover-letter fields remain solely in `application.toml`.

Measure and render one opportunity from the repository root:

```sh
bash ./ccvl measure-opportunity <organisation-key> <position-key>
bash ./ccvl build-opportunity <organisation-key> <position-key>
```

On Windows:

```powershell
.\ccvl.cmd measure-opportunity <organisation-key> <position-key>
.\ccvl.cmd build-opportunity <organisation-key> <position-key>
```

No locale or page argument is needed: the record owns both. The build writes
`output/cv.pdf` and, when enabled, `output/cl.pdf` directly below the keyed
opportunity. Disabling the letter yields a CV-only package and removes any
stale generated `cl.pdf` from an earlier build.
