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
`application.json`. It must express:

```text
target profile | differentiation | two evidenced results | value offered
```

The public showcase may combine this formula with an invitation to contact the
author. A real application must be target-specific.

## Verification

Render every affected locale and preset. Require the requested two-, three-, or
four-page count, inspect every rendered page, and extract the PDF text layer.
Reject clipped content, accidental extra pages, missing glyphs, placeholders,
or a Summary that exceeds its application constraint. Run the matching platform
`check` command before completion.
