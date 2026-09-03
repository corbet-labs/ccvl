# ccvl

[![CI](https://github.com/corbet-labs/ccvl/actions/workflows/ci.yml/badge.svg)](https://github.com/corbet-labs/ccvl/actions/workflows/ci.yml)
[![Skill evaluation](https://github.com/corbet-labs/ccvl/actions/workflows/skill-eval.yml/badge.svg)](https://github.com/corbet-labs/ccvl/actions/workflows/skill-eval.yml)

ccvl is a local-first, forkable CV and application system built with Typst. It
ships a real bilingual career profile as its working example, a controllable
Harvard-style presentation layer, strict document checks, and portable agent
skills for the complete application loop.

The showcase is intentionally a real CV rather than fictional sample data. It
serves two purposes: demonstrating the system at production quality and making
its author discoverable for suitable roles. It is reference-only personal
content, not a reusable template. New users start from the neutral templates
and replace the profile and evidence with their own verified facts.

## Showcase and open application

[View the bilingual CV and cover-letter showcase](SHOWCASE.md). The personal
content is visible for professional evaluation, but is not a reusable template.

## What is included

- German and English CVs with exact two-, three-, and four-page variants and
  an always-five-line Summary.
- A target-neutral cover letter with six measured paragraphs and five highlights.
- One schema-validated `application.json` per concrete opportunity.
- Measured minimum, target, and maximum bounds for controlled line width,
  cover-letter spacing, and highlight position.
- Shared Typst components, bundled fonts, and reproducible build commands.
- Eight agent skills for setup, evidence-backed profiles, target research, CV
  work, applications, interview preparation, upskilling, and outcome tracking.
- Privacy and provenance rules for keeping personal application data in a
  private downstream repository.

## Quick start

No Git or Typst experience is required. [Download and extract the source
archive](https://github.com/corbet-labs/ccvl/archive/refs/heads/main.zip), or
clone the repository if you already use Git. Open the folder in a
filesystem-capable coding agent and ask it to set up ccvl using `AGENTS.md`.
The complete novice and terminal workflows are in [Getting
started](docs/getting-started.md).

```sh
git clone https://github.com/corbet-labs/ccvl.git
cd ccvl
bash ./ccvl setup
bash ./ccvl check
bash ./ccvl build
```

On native Windows, use the matching dispatcher from Command Prompt or
PowerShell:

```powershell
.\ccvl.cmd setup
.\ccvl.cmd check
.\ccvl.cmd build
```

Generated PDFs are written below `cvl/cv/output/` and `cvl/cl/output/`.
The same commands work in a downloaded source archive; Git knowledge is not
required. Linux x86_64/aarch64, macOS Intel/Apple Silicon, and Windows
x86_64/ARM64 use pinned native tools. Existing POSIX Just users may use the
equivalent `just` recipes.

## Make it yours

Do not edit a public fork into a personal application workspace. Clone ccvl
into a private standalone repository that retains ccvl as `upstream`; then put
evidence, targets, applications, submissions, and outcomes only in that private
downstream. See [Private downstreams](docs/private-downstream.md).

The checked-in showcase is reference material, not evidence about a new user.
Start with the `ccvl-profile` skill, establish a verified fact base, and only
then replace the showcase content. Its personal claims and wording may not be
reused as template content. Claims drawn from the new user's own evidence may
be selected and compressed, but must never be invented.

## Agent workflows

Canonical skills live under `.agents/skills/`:

- `ccvl-install`
- `ccvl-profile`
- `ccvl-targets`
- `ccvl-cv`
- `ccvl-apply`
- `ccvl-interview`
- `ccvl-upskill`
- `ccvl-outcome`

Repository-wide operating rules are in [AGENTS.md](AGENTS.md). The data model
is documented in [docs/data-model.md](docs/data-model.md), and the deterministic
plus small-model checks are described in [docs/testing.md](docs/testing.md).
The [skill map](docs/skills.md) defines the eight ownership boundaries and what
is deliberately left to an explicitly connected system or user action.

## License

ccvl uses path-specific licensing:

- software, Typst sources, scripts, and skills: FSL-1.1-ALv2;
- documentation and neutral templates: CC-BY-4.0;
- personal showcase data and Typst content, generated signature, and rendered
  showcase PDFs: LicenseRef-CCVL-Personal-Content (all rights reserved, with
  only narrow evaluation and private replacement permissions);
- bundled fonts: OFL-1.1.

FSL is a Fair Source license, not an OSI Open Source license. Each published
version becomes available under Apache-2.0 two years after that version was
made available. See [LICENSE.md](LICENSE.md) and [REUSE.toml](REUSE.toml) for
the exact per-path mapping.
