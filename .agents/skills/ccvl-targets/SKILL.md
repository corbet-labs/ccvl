---
name: ccvl-targets
description: Research and maintain a MECE target landscape of organisations, functions, and role families before evaluating individual vacancies.
---

# Map the target landscape

Build a durable view of where the candidate should look, independent of any one
vacancy.

## Model

Keep these axes separate: organisation, geography, market, function, role
family, seniority, priority, rationale, and provenance. One organisation may
map to several functions or role families. Do not duplicate the same concept
under different labels merely to increase keyword coverage.

## Workflow

1. Load the verified profile and the user's stated direction.
2. Research current organisations and role families with attributable sources.
3. Separate observed facts from fit hypotheses.
4. Normalise aliases, then check the complete map for overlaps and gaps.
5. Save organisation records below private `targets/` using
   `../../../templates/target.md`.

A specific posting is not a target record. Create its canonical
`applications/<job-id>/application.json` through `ccvl-apply`.

If the user explicitly connects another typed workspace, use its target and job
operations instead of parallel files. ccvl itself must not grow a local
imitation of an external corpus.
