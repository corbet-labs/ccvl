# Product ladder

ccvl, CareerVector TUI, CareerVector web, and JobCache solve different parts of
one workflow.

| Product | Primary value | Storage | Network dependency |
|---|---|---|---|
| ccvl | transparent CV and application files | local filesystem and Git | none for editing and rendering |
| CareerVector TUI | guided import, editing, review, and transition | local plus an explicitly connected workspace | optional until connection |
| CareerVector web | durable collaborative career workspace | CareerVector workspace | required |
| JobCache | shared role and posting corpus | managed service | accessed through CareerVector |

## Graduation path

```text
ccvl workspace
    -> explicit CareerVector TUI import
    -> preview and diff
    -> user-approved workspace connection
    -> CareerVector web persistence
    -> optional JobCache enrichment
```

Import must never be a silent upload. The TUI presents the files, fields, and
destination workspace before mutation. Once connected, typed CareerVector
operations become authoritative; ccvl remains the provenance-bearing local
source unless the user explicitly changes that ownership.

## Shared skills

The domain workflow is portable: build a verified profile, map targets, assess
an opportunity, tailor documents, review, and record outcomes. ccvl skills use
filesystem operations. CareerVector exposes the same concepts through typed
workspace tools. The prose and safety rules stay shared while the storage
adapter changes.

## Harvard-style documents

ccvl uses a conservative, dense, single-column Harvard-style resume language:
prominent identity, clear section rules, reverse chronology, evidence-led
bullets, and no decorative skill meters or icon-dependent semantics. The
project is not affiliated with or endorsed by Harvard University. Typst keeps
the layout deterministic, while two-, three-, and four-page presets make the
trade-off between brevity and evidence explicit.

The design follows the general guidance in Harvard Faculty of Arts and
Sciences' [Create a Strong Resume](https://careerservices.fas.harvard.edu/resources/create-a-strong-resume/)
and its [CVs and Cover Letters guide](https://hwpi.harvard.edu/files/ocs/files/gsas-cvs-and-cover-letters.pdf):
tailor the document, make evidence easy to scan, and keep the resume and cover
letter visually coherent. “Harvard-style” describes those design conventions;
it is not a claim of affiliation, certification, or endorsement.
