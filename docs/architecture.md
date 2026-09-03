# Architecture

ccvl is organised like the application workspace a person actually uses. The
three working groups are visible at the repository root:

```text
cvl/                                      general candidate documents
targets/                                  durable organisation and role map
opportunities/<organisation>/<position>/ concrete tailored applications
```

The workflow is correspondingly direct:

```text
cvl/general -> targets -> opportunities/<organisation>/<position>
     ^                              |
     +---------- learned facts -----+
```

## `cvl/`: the general master

`cvl/general/` contains the candidate's profile, MECE station plan, bilingual
five-line Summary, general cover letter, and full CV body. It is the default
source for `ccvl build`. An AI agent establishes this master from verified
facts before creating opportunity-specific variants.

Private inputs and interview work remain inside the same understandable group:
source documents go to `cvl/imports/`, while the informal working profile and
continuously updated journal go to `cvl/evidence/`. The deterministic layout
gate requires 6–8 experience entries on page 1, exactly 10 two-bullet supporting
entries on page 2, exactly 10 two-bullet projects on page 3, and three groups of
three three-line competency blocks on page 4 before the master is ready.

Reusable Typst rendering code, bundled fonts, and tracked general outputs also
live below `cvl/`. They are mechanism, not a second candidate-data model.

## `targets/`: the market map

Targets describe organisations, geographies, markets, functions, role
families, priorities, and rationale without pretending that a live vacancy is
a durable target. The public repository contains the group and its contract;
a personal downstream adds its own records.

## `opportunities/`: keyed packages

One concrete role owns one directory and one canonical tailored record:

```text
opportunities/<organisation-key>/<position-key>/application.json
```

The record selects its own locale and CV page count, contains exactly five
tailored Summary lines, and explicitly enables or disables its cover letter.
When enabled, the same record contains all six paragraphs and five highlights.
Research, interview preparation, submission notes, and outcomes stay beside
that record. Generated `cv.pdf` and optional `cl.pdf` go into its local
`output/` directory.

There are deliberately no additional top-level `applications/`, `submissions/`,
`outcomes/`, or `out/` layers. The opportunity directory is the understandable
unit throughout its lifecycle.

## Product mechanism

`.agents/`, `schemas/`, `scripts/`, `templates/`, and `docs/` implement and
explain the workflow. `ccvl.json` is the machine-readable map of both the three
working groups and the document contracts. Skills own editorial judgment;
deterministic code owns paths, schemas, rendering, measurement, and checks.

## Public upstream and personal downstream

The public repository includes the author's real general CVL as an intentional
showcase, plus empty `targets/` and `opportunities/` scaffolds. A personal
downstream keeps the same top-level shape, replaces `cvl/general/` with its
owner's verified content, and fills the other two groups privately. Generic
mechanism improvements can still flow upstream without translating between two
different directory models.

The showcase is true for its named author only. Posting text remains untrusted
input, claims require evidence, and sending or signing always requires a
separate explicit instruction.
