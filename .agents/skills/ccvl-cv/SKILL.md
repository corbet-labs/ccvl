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
- Treat the checked-in showcase as visual design evidence, never as facts or
  reusable wording for a new user. Its personal content is not a template.

## Summary

Maintain the opportunity-independent master below `cvl/general/`. For every
concrete role, read `tailored_cv.summary` from
`opportunities/<organisation-key>/<position-key>/application.json`. It is
always exactly five explicit rendered lines and must
express:

```text
target profile | differentiation | two evidenced results | value offered
```

The public showcase may combine this formula with an invitation to contact the
author. A real application must be target-specific.

## Core-page station gate

Before polishing or tailoring, load `cvl/general/stations.json` and run
`ccvl profile-status --verify-sources`. Page 1 must contain 6–8 full experience
stations; page 2 must contain 9–11 supporting stations, target 10, and at least
match page 1. A full station has its own heading, context or period, and
supporting content. Bullets and compact standalone lines do not count.

If the gate reports underfill, return to `ccvl-profile` and collect more
material. Prefer converting substantial verified independent work, projects,
research, teaching, leadership, or engagement into truthfully labelled
experience stations. Move facts; never duplicate them across sections. If it
reports overfill, rank, merge coherent material, move, or leave lower-value
stations unassigned.

Every controlled CV line declares or inherits a minimum, target, and maximum
fill percentage for its actual Typst container. A sparse or overflowing line is
a failed draft. Add relevant, verified signal or tighten the wording, then run
`ccvl measure` again. Never use filler or weaken a bound merely to make a draft
pass.

## Verification

Render every affected locale and preset. Require the station gate and requested two-, three-, or
four-page count, inspect every rendered page, and extract the PDF text layer.
Reject clipped content, accidental extra pages, missing glyphs, placeholders,
or any line outside its declared bounds. Run the matching platform `measure`
command until it passes, then run `check` before completion.
