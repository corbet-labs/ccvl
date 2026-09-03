# Cover-letter contract

Every ccvl cover letter contains exactly five paragraphs, targets 15 explicit
body lines, accepts 14–16, and contains five one-line highlights. The structure
and bounded visual rhythm are stable; the evidence, paragraph allocation, and
target fit are not.

## Shared paragraph budgets

Paragraphs may trade lines within their region:

- paragraphs 1–3 target nine rendered lines and accept 8–10;
- paragraphs 4–5 target six rendered lines and accept 5–7;
- the complete body targets 15 rendered lines and accepts 14–16.

All five paragraphs remain visibly separate and non-empty. One paragraph may
therefore use two lines while another in the same region uses four. The region,
not each paragraph, owns the line budget. This preserves editorial flexibility
without letting the letter silently grow or collapse.

The five paragraphs should:

1. Name the role or, for the showcase, the type of problem sought.
2. Establish the strongest relevant evidence anchor.
3. Add a complementary evidence anchor from another capability domain.
4. Explain the value created by that combination for the target.
5. Close with a direct, low-friction invitation to talk.

## Five near-centred highlights

The five highlights form the visual transition between the first three and
last two paragraphs. They are a fast evidence index, not a second letter. Each
uses one measured line with a recognisable heading and concrete evidence.
Together they cover the role's main selection dimensions without repeating the
paragraphs verbatim.

## Vertical rhythm

The renderer places the header, subject, salutation, five paragraphs,
highlights, and closing in one full-height A4 grid. Nine equal flexible gaps
distribute the remaining height instead of collecting it in two empty slabs.
The manifest targets a 45 pt gap and accepts 30–55 pt. The highlight centre
targets 61% of the usable page height and accepts 56–67%, allowing recipient
details and one-line body variation without losing the intended composition.

Both values are measured from the actual rendered Typst boxes. A sparse or
over-compressed vertical result fails `ccvl measure` and prompts another
content or line-allocation iteration. `ccvl.json` is authoritative for the
minimum, target, and maximum values.

## Measured lines

Every body and highlight line declares `min_fill`, `target_fill`, and
`max_fill` as percentages of its actual Typst container width. The public
showcase uses 65/86/100 for body lines and 60/82/100 for highlights. Both a
sparse line and an overflowing line fail the build. Rewrite with relevant,
verified signal, then rerun `bash ./ccvl measure` or `.\ccvl.cmd measure` until
all lines pass. A failure prompts iteration; it never prompts filler, invented
claims, condensed type, or opportunistically weaker bounds.

The public showcase is target-neutral and describes the named author. A real
application replaces the role, company fit, evidence selection, and call to
action while keeping every claim traceable to the private evidence base.
