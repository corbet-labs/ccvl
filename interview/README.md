# Private user knowledge

This directory is where an agent builds the candidate's source-linked fact
base, preferences, visible journal, and CV station allocation.

Start `profile.md`, `journal.md`, and `stations.toml` from the neutral
scaffolds under `.agent/scaffolds/interview/`. Put read-only source documents
in `imports/`. The working records may contain unverified or conflicted
material and are private by default; only verified, uniquely owned facts may
be promoted into `cvl/` or a concrete opportunity.

General facts and preferences learned about the user belong here. Research
about a company or role belongs inside
`opportunities/<organisation>/<position>/`; ccvl has no standalone market map.
