# General CV and cover letter

This directory is the candidate's general, opportunity-independent document
base. An AI authoring agent should build and maintain it before tailoring any
specific application.

- `profile.json` contains public identity and contact fields.
- `stations.json` is the MECE inventory and page assignment for full entries on
  the first two CV pages.
- `de-ch/application.json` and `en-ch/application.json` contain the five-line
  general Summary and the general cover letter.
- `de-ch/cv.typ` and `en-ch/cv.typ` contain the full locale-specific CV body.

The layout is machine-checked: page 1 accepts 6–8 experience stations. Page 2
contains exactly 10 supporting stations with two bullets each; page 3 contains
exactly 10 projects with two bullets each; page 4 contains three competency
groups with three blocks and three keyword lines per block. Compact standalone
lines do not count. Run `ccvl profile-status --verify-sources` before treating
the general CV as complete.

The checked-in files describe the repository author and demonstrate a finished
workspace. In a personal downstream, replace them with the user's own verified
facts and wording. Opportunity-specific changes belong under
`../../opportunities/<organisation-key>/<position-key>/`, never in this master.
