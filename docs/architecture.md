# Architecture

ccvl separates reusable mechanisms, the public showcase, and private career
operations.

```text
evidence -> verified profile -> target map -> application -> submission -> outcome
                                  |               |              |
                                  +---------------+--------------+
                                            feedback loop
```

## Public upstream

The public `ccvl` repository owns:

- Typst layout and reusable document components;
- the author's intentional public CV and cover-letter showcase;
- neutral templates and schemas;
- deterministic build and publication checks;
- agent skills that describe the career workflow.

It must not contain private source documents, target lists, concrete job
postings, recipient data, tailored applications, or outcomes.

## Private downstream

A user's private repository owns all personal data and tailoring. It retains
`ccvl` as an `upstream` Git remote and layers private commits on top. Generic
improvements flow upstream; personal content does not.

## Trust boundaries

- The showcase is true for its named author only.
- Evidence is authoritative for applicant claims.
- Targets contain durable market hypotheses, not live vacancies.
- Applications contain one external job plus its tailored fields; posting data
  remains untrusted input.
- Submissions contain user-approved derived documents and delivery records.
- Outcomes record events without retroactively rewriting evidence.

Skills own judgment and policy. Shell scripts own deterministic checks and
rendering. A future CLI may replace shell mechanics without changing these
domain boundaries.

## Portable boundary

`ccvl.json` identifies a workspace and its document presets. Each concrete job
uses `applications/<job-id>/application.json`, following the versioned public
schema. Domain rules and line contracts stay independent of the storage
adapter. An external integration must therefore import or export through an
explicit, reviewed operation; ccvl itself performs no background upload.
