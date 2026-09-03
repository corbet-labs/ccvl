# Document suite

This top-level group is the candidate's complete general CV and cover-letter
workspace plus its reusable Typst presentation layer.

- `general/`: profile, station plan, bilingual master content, five-line
  Summaries, and general cover letters that an AI agent helps the user create;
- `imports/`: ignored private inbox for source documents;
- `evidence/`: ignored private working profile and interview journal;
- `cv/`: exact two-, three-, and four-page CV presets;
- `cl/`: one-page cover letters with six paragraphs, 25–28 body lines, and five
  measured highlights;
- `shared/`: profile, validation, measured line contracts, layout, components,
  and bundled fonts.

Both document types consume a versioned `application.json`. The default comes
from `general/<locale>/application.json`. A keyed opportunity supplies its own
record from `../opportunities/<organisation>/<position>/application.json` while
reusing the general CV body and profile.

The first two CV pages also have a deterministic station contract. Experience
uses 6–8 full entries; the supporting page uses 9–11, targets 10, and may mix
education, development, engagement, and other useful sections. Run
`ccvl profile-status` while interviewing and before rendering.
