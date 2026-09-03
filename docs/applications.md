# One file per opportunity

Every concrete opportunity has exactly one canonical tailored-data file:

```text
applications/<job-id>/application.json
```

Create it from `templates/application.json`. Schema version 2 contains:

- `job`: vacancy, organisation, source, description, context, notes, and
  recipient;
- `tailored_cv.summary`: exactly five measured line objects;
- `tailored_cl.paragraphs`: exactly five paragraphs targeting a 9+6 body-line
  allocation, with one line of tolerance per region and 14–16 lines overall;
- `tailored_cl.highlights`: exactly five measured one-line highlights.

Every measured line has this portable shape:

```json
{
  "text": "One explicit rendered line",
  "min_fill": 65,
  "target_fill": 86,
  "max_fill": 100
}
```

Fill percentages are resolved against the actual Typst container. The schema
checks shape, values, and ordering; the renderer measures glyph widths with the
bundled font. A line below its minimum or above its maximum is a failed draft
and must be rewritten and measured again.

An archived posting, research notes, or correspondence may sit beside the JSON
file, but must not duplicate its tailored fields. The versioned JSON contract
is intentionally independent of its storage adapter, so another reviewed tool
can import it without turning Markdown or PDFs into competing sources of truth.

`application_date` is reserved for the rendered letter and must survive any
reviewed import or export unchanged.

Measure and render one private application from the repository root:

```sh
bash ./ccvl measure --application applications/<job-id>/application.json --locale de-ch
bash ./ccvl build-application applications/<job-id>/application.json de-ch 4
```

On Windows, use:

```powershell
.\ccvl.cmd measure --application applications\<job-id>\application.json --locale de-ch
.\ccvl.cmd build-application applications\<job-id>\application.json de-ch 4
```

The build writes `cv.pdf` and `cl.pdf` below the ignored `out/<job-id>/`
directory. Use `en-ch` for English and select the two-, three-, or four-page CV
preset with the final build argument.
