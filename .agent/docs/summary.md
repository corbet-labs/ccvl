# Summary contract

Every Summary is always exactly five explicit rendered lines. It is not a prose
block that happens to wrap to roughly five lines. The public Summary is both a
working example and an invitation to contact its author. Its fifth line exposes
the adaptation formula:

```text
target profile | differentiation | two evidenced results | value offered
```

For a real application, the formula remains but the prose must be rewritten for
the specific opportunity. Keywords may improve retrieval, but they never turn
an unsupported capability into a fact. Use plain language that a recruiter can
understand and a specialist can recognise.

Each line in `tailored_cv.summary` declares `min_fill`, `target_fill`, and
`max_fill` as percentages of its actual Typst container width. The showcase
uses a 60% minimum, 82% target, and 100% maximum. Underfill and overflow are
both failures: add relevant, verified signal or tighten the wording, then run
`bash ./ccvl measure` or `.\ccvl.cmd measure` again. Never pass measurement by
adding filler or by weakening a bound to fit unchanged prose.
