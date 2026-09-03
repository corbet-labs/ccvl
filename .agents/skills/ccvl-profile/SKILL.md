---
name: ccvl-profile
description: Build or reconcile an evidence-backed candidate profile from CVs, records, projects, interviews, and user-confirmed facts before writing applications.
---

# Build a verified profile

Create a trustworthy private fact base, then project its approved public
contact fields into `profile.json`.

## Sources

Use source documents read-only. Suitable inputs include existing CVs, diplomas,
references, work samples, public repositories, project records, and a structured
interview with the user. Preserve source paths or URLs and dates.

## Fact handling

- Cross-reference sources before resolving discrepancies.
- Record each claim as `verified`, `conflicted`, or `unverified` using
  `../../../templates/profile.md` and the model in
  `../../../docs/data-model.md`.
- User confirmation is valid provenance. Record what was confirmed rather than
  inventing a supporting document.
- Independent work, hobbies, side ventures, and repairs are legitimate evidence
  at their actual scope. Do not recast them as employment, customers, formal
  businesses, adoption, or revenue without evidence.
- Preserve useful negative space: unknown is different from empty or false.

## Output

In local ccvl mode, write private evidence below `evidence/` and produce a
validated private `profile.json` from `templates/profile.json`. In CareerVector
mode, use only the available typed profile and evidence operations; do not
create a second filesystem source of truth.

Before making a profile public, show the exact identifier and claim manifest to
the user. The checked-in ccvl showcase describes its named author only.
