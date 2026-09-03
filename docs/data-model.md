# Workspace data model

The data model follows the three visible top-level working groups. Each fact is
stored once, where a person would expect to find it.

| Group | Unit | Contains | Must not contain |
|---|---|---|---|
| `cvl/` | candidate | general profile, verified evidence, master CV and CL | one vacancy's tailoring |
| `targets/` | organisation or target set | market map, role families, priority, rationale | a live posting |
| `opportunities/` | organisation key + position key | posting, tailored CV/CL, preparation and observed outcome | duplicated master CV content |

## Candidate evidence

The general CVL may be supported by source-linked records below `cvl/evidence/`
in a private downstream. Every candidate claim has one of three states:

- `verified`: supported by a named source or explicit user confirmation;
- `conflicted`: sources disagree and the conflict remains visible;
- `unverified`: potentially useful, but prohibited from application output.

Absence of evidence is not evidence of absence. Estimates, inferences, hobby
work, and side initiatives retain their real scope.

The profile interview maintains three distinct views of the same candidate:

- `cvl/evidence/profile.md` is the informal, information-rich working portrait;
- `cvl/evidence/journal.md` records inputs, progress, conflicts, and deferred prompts;
- `cvl/general/stations.json` assigns verified atomic facts to CV stations.

A station has one truthful kind, one final page and section, and one or more
uniquely owned fact IDs. The distinction between kind and placement lets
substantial independent work appear under Experience without becoming a false
employment claim. See [Profile interview and station
allocation](profile-interview.md).

## Target taxonomy

Keep organisation, geography, industry or market, function, role family,
seniority, priority, rationale, and source as independent axes. One
organisation may map to several functions and role families. A concrete
vacancy is linked from the target but stored only under `opportunities/`.

## Opportunity identity

The stable identity is its path:

```text
opportunities/<organisation-key>/<position-key>/
```

Keys use lowercase ASCII letters, numbers, hyphens, or underscores. There are
no generic `companies/` or `positions/` levels. The canonical tailored record
is always `application.json`; its generated documents always belong in the
adjacent `output/` directory.

The JSON record owns:

- source and role context;
- language and application date;
- selected CV page count;
- exactly five tailored Summary lines;
- whether a cover letter is required;
- when enabled, six measured paragraphs and five measured highlights.

Posting archives and correspondence may sit beside the record but never
duplicate its tailored fields. Interviews and outcomes add adjacent Markdown
records without retroactively rewriting what was submitted.
