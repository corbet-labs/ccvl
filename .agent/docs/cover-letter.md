# Cover-letter contract

Every ccvl cover letter contains exactly six body paragraphs and five one-line
highlights. The highlights sit between paragraphs 3 and 4. Paragraph 1 opens in
exactly three lines; paragraph 6 mirrors it with a warm two- or preferably
three-line close. The four central paragraphs carry the evidence and target
case across 20–22 lines.

`ccvl.json` is the machine-readable source of truth. Each paragraph definition
contains its number, semantic role, purpose, and line bounds, making the
contract self-describing for both people and agents.

## Paragraph map

| Block | Role | Purpose | Line contract |
|---|---|---|---:|
| Paragraph 1 | Positioning | Name the target and establish immediate fit. | exactly 3 |
| Paragraph 2 | Primary evidence | Prove the strongest relevant experience and results. | 5–7; target 6 |
| Paragraph 3 | Complementary evidence | Add a second capability domain and the career-wide pattern. | 5–7; target 6 |
| Highlights | Evidence index | Surface five selection dimensions without repeating the letter. | exactly 5 × 1 |
| Paragraph 4 | Differentiation | Explain the value created by the combined evidence. | 5–7; target 6 |
| Paragraph 5 | Target fit | Connect that value to the specific organisation and opportunity. | 5–7; target 6 |
| Paragraph 6 | Warm close | Invite a conversation with warmth and low friction. | 2–3; target 3 |

The valediction and signature follow paragraph 6 and do not count as a seventh
paragraph.

## Shared line budgets

Paragraphs 2–5 each start with a five-line floor and may use up to two flexible
lines. Their overlapping regional contracts are:

- paragraphs 2–3: 10–12 lines;
- paragraphs 4–5: 10–12 lines;
- paragraphs 2–5 together: 20–22 lines.

A pair total of 10 or 12 is preferred. Eleven remains valid, but `ccvl measure`
reports it as a non-blocking preference warning because the asymmetry usually
looks weaker. At 12 lines, 6+6 is preferred; 5+7 and 7+5 remain valid. The
default showcase uses `3 | 6 | 6 | 5 | 5 | 3`: 22 central lines and 28 body
lines overall. A two-line paragraph 6 is also valid but warns because three
lines provide the preferred visual and tonal mirror of paragraph 1.

## Justification and paragraph integrity

Every body line is explicit and measured before justification. Its natural
glyph width must cover at least 75% of the available measure, targets 90%,
and may never exceed 100% — except a paragraph's closing line, which shares
the uniform closing-line maximum of 102% with the CV Summary. This prevents
a short stranded line from being hidden by extreme word spacing.
Non-final lines are then justified; the final line stays
ragged but remains subject to the same natural-width floor.

Each paragraph is an unbreakable Typst block. Manual line breaks, the one-page
contract, and the 75% floor together permit zero widows, orphans, wrapped lines,
or sparse paragraph endings. Underfill and overflow both fail the draft and
prompt another evidence-backed rewrite.

## Five highlights

The highlights form the visual and argumentative hinge between evidence and
application. Each is exactly one measured line with a recognisable heading and
concrete evidence. Together they cover the target's main selection dimensions
without duplicating the prose verbatim.

## Vertical rhythm

The renderer places the header, subject, salutation, six paragraphs,
highlights, and valediction/signature in one full-height A4 grid. Ten equal
flexible gaps distribute the remaining height instead of collecting it in empty
slabs. A gap targets 20 pt and must remain within 12–30 pt. The highlight centre
targets 56% of usable page height and must remain within 50–60%. A sparse or
over-compressed page therefore fails deterministically even when every
individual line fits.

Both values come from the actual rendered Typst boxes. Recipient details and
accepted line-budget variation may move the highlights slightly away from the
geometric centre without abandoning the composition.

## Iteration contract

Run `bash ./ccvl measure` or `.\ccvl.cmd measure`. A hard line, structure, or
layout violation fails. A dispreferred 11-line pair warns but remains valid.
Rewrite with relevant, verified signal and rerun measurement; never respond by
adding filler, inventing a claim, condensing the type, or weakening the bounds.

The public showcase is target-neutral and describes the named author. A real
application replaces the role, company fit, evidence selection, and invitation
while keeping every claim traceable to the private evidence base.
