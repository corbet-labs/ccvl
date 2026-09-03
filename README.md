# ccvl

ccvl is a local-first, forkable CV and application system built with Typst. It
ships a real bilingual career profile as its working example, a controllable
Harvard-style presentation layer, strict document checks, and portable agent
skills for the complete application loop.

The showcase is intentionally a real CV rather than fictional sample data. It
serves two purposes: demonstrating the system at production quality and making
its author discoverable for suitable roles. New users replace the profile and
evidence with their own verified facts.

## Showcase and open application

Julian Corbet works where innovation management and technology meet strategy
and finance. If that combination fits a real problem on your team, the demo is
also an invitation to talk:

| Language | CV | Cover letter |
|---|---|---|
| Deutsch | [four-page CV](cvl/cv/output/de-ch/4pager/cv.pdf) | [open cover letter](cvl/cl/output/de-ch/cl.pdf) |
| English | [four-page CV](cvl/cv/output/en-ch/4pager/cv.pdf) | [open cover letter](cvl/cl/output/en-ch/cl.pdf) |

The two- and three-page CV presets are available in the same output tree.

## What is included

- German and English CVs with exact two-, three-, and four-page variants.
- A target-neutral cover letter with five paragraphs and five highlights.
- One CareerVector-aligned `application.json` per concrete opportunity.
- Shared Typst components, bundled fonts, and reproducible build commands.
- Agent skills for setup, evidence-backed profiles, target research, CV work,
  applications, and outcome tracking.
- Privacy and provenance rules for keeping personal application data in a
  private downstream repository.

## Quick start

```sh
git clone https://github.com/corbet-labs/ccvl.git
cd ccvl
git lfs pull
just doctor
just check
just build
```

Generated PDFs are written below `cvl/cv/output/` and `cvl/cl/output/`.

## Make it yours

Do not edit a public fork into a personal application workspace. Clone ccvl
into a private standalone repository that retains ccvl as `upstream`; then put
evidence, targets, applications, submissions, and outcomes only in that private
downstream. See [Private downstreams](docs/private-downstream.md).

The checked-in showcase is reference material, not evidence about a new user.
Start with the `ccvl-profile` skill, establish a verified fact base, and only
then replace the showcase content. Claims may be selected and compressed, but
must never be invented.

## Agent workflows

Canonical skills live under `.agents/skills/`:

- `ccvl-install`
- `ccvl-profile`
- `ccvl-targets`
- `ccvl-cv`
- `ccvl-apply`
- `ccvl-outcome`

Repository-wide operating rules are in [AGENTS.md](AGENTS.md). The data model
is documented in [docs/data-model.md](docs/data-model.md).

## License

ccvl uses path-specific licensing:

- software, Typst sources, scripts, and skills: FSL-1.1-ALv2;
- documentation and neutral templates: CC-BY-4.0;
- personal showcase data and Typst content, generated signature, and rendered
  showcase PDFs: CC-BY-ND-4.0;
- bundled fonts: OFL-1.1.

FSL is a Fair Source license, not an OSI Open Source license. Each published
version becomes available under Apache-2.0 two years after that version was
made available. See [LICENSE.md](LICENSE.md) and [REUSE.toml](REUSE.toml) for
the exact per-path mapping.

## From local files to CareerVector

ccvl deliberately remains a transparent desktop workspace with no account,
database, or JobCache dependency. Its versioned manifest and application files
form the import boundary for CareerVector TUI. Moving into CareerVector adds a
persistent web workspace and JobCache-backed role and posting data; it is a
visible user action, never a background upload. See
[The product ladder](docs/ecosystem.md).
