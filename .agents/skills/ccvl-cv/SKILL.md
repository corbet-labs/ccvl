---
name: ccvl-cv
description: Write, tailor, render, and verify ccvl CV variants when Summary, experience, projects, competencies, keywords, or page presets change.
---

# Create and revise a ccvl CV

Preserve the Harvard-style hierarchy and make the document legible to both
recruiters and specialists.

## Writing contract

- Use the simplest language that a recruiter can understand while retaining
  terms a domain specialist will recognise.
- Lead with outcome or scale, then ownership and method. Remove filler and
  duplicated meaning.
- Use only verified profile claims. Keywords improve retrieval but do not
  create factual permission.
- Keep capability groups mutually exclusive and collectively useful. Prefer a
  few recognisable terms over keyword stuffing.
- Treat the checked-in showcase as design evidence, never as facts about a new
  user.

## Summary

For every concrete role, read `tailored_cv.summary` from its
`application.json`. It is always exactly five explicit rendered lines and must
express:

```text
target profile | differentiation | two evidenced results | value offered
```

The public showcase may combine this formula with an invitation to contact the
author. A real application must be target-specific.

Every controlled CV line declares or inherits a minimum, target, and maximum
fill percentage for its actual Typst container. A sparse or overflowing line is
a failed draft. Add relevant, verified signal or tighten the wording, then run
`ccvl measure` again. Never use filler or weaken a bound merely to make a draft
pass.

## Verification

Render every affected locale and preset. Require the requested two-, three-, or
four-page count, inspect every rendered page, and extract the PDF text layer.
Reject clipped content, accidental extra pages, missing glyphs, placeholders,
or any line outside its declared bounds. Run the matching platform `measure`
command until it passes, then run `check` before completion.
