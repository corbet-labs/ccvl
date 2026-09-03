# Privacy model

The public showcase deliberately contains the identifiers listed in
`PUBLIC_IDENTIFIERS.md`. Everything else is private by default.

## Never publish by default

- raw CVs, diplomas, references, contracts, or certificates;
- real handwritten signatures, street addresses, dates of birth, or identity
  files;
- target-company maps and private research notes;
- complete job postings when redistribution rights are unclear;
- recipient names, correspondence, tailored letters, or submission records;
- interview feedback, rejections, offers, compensation, or outcomes;
- credentials, cookies, session data, or portal exports.

The public repository ignores conventional private roots and rejects them in
`just public-check`. A deny-list cannot understand context; a human or agent
must still inspect the complete staged tree and diff before publication.

## Public forks

A public GitHub fork is suitable for generic improvements, not a personal job
search. Anyone personalising ccvl should use a standalone private downstream.
