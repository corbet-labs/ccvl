# Skill map

ccvl declares eight canonical skills in `ccvl.json`. Together they cover the
portable application lifecycle without duplicating ownership.

| Skill | Owns | Does not own |
|---|---|---|
| `ccvl-install` | environment diagnosis, local bootstrap, verification | profile or document edits |
| `ccvl-profile` | source ingestion, conversational journal, claim states, MECE station coverage, candidate facts and voice | target hypotheses |
| `ccvl-targets` | MECE organisations, markets, functions, and role families | concrete vacancies |
| `ccvl-cv` | CV selection, wording, layout, ATS and render checks | unsupported claims |
| `ccvl-apply` | one vacancy, fit decision, Summary, six-paragraph letter, review | submission authority |
| `ccvl-interview` | stage-specific preparation and honest practice | outcome history |
| `ccvl-upskill` | recurring gaps, learning priorities, proof plan | automatic enrolment or proficiency claims |
| `ccvl-outcome` | observed events, exact feedback, funnel evidence, calibration | invented causes |

Profile expansion, behavioural evidence, and writing style are facets of one
verified profile rather than separate skills. Opportunity evaluation, cover
letter drafting, application-form preparation, and an independent review pass
belong to one concrete application. This keeps the skill set small enough for
limited-context agents while retaining the important controls.

Country-specific portal scrapers are intentionally not bundled. ccvl accepts a
posting or authorised reference locally; any persistent discovery service must
arrive through an explicit, reviewed connection. Sending, signing, buying,
enrolling, recording, and portal submission always remain separate
user-authorised actions rather than skills that trigger themselves.
