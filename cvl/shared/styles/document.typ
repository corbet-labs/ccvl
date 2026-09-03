// Shared presentation primitives for CVs and cover letters.

#let cv-bullet() = box(width: 10.5pt, height: 7.35pt, align(horizon, align(center, polygon(
  fill: rgb("#000000"),
  (0pt, 0pt),
  (4.41pt, 2.75625pt),
  (0pt, 5.5125pt),
))))

// Entry heading (bold). Override size: #cv-h(size: 14pt)[...]
#let cv-h(size: 11pt, t) = { text(size: size, weight: "bold", t) }
#let cv-hu(size: 11pt, t) = {
  set strong(delta: -300)
  text(size: size, weight: "bold", t)
}
// Entry subheading. Override size: #cv-s(size: 9pt)[...]
#let cv-s(size: 10pt, t) = text(size: size, t)
// Bullet row. Override indent/gutter: #cv-b(indent: 12pt)[...]
#let cv-b(indent: 10.5pt, gutter: 0pt, t) = grid(
  columns: (indent, 1fr),
  gutter: gutter,
  cv-bullet(), t,
)
// Sub-bullet row (indented)
#let cv-sb(indent: 10.5pt, gutter: 0pt, t) = pad(left: indent, grid(
  columns: (indent, 1fr),
  gutter: gutter,
  cv-bullet(), t,
))

#let cv-superheading-outer-spacing = 17.85pt
#let cv-compact-heading-spacing = 9.45pt
#let cv-spacious-heading-spacing = 19.35pt
#let cv-entry-spacing = 11.75pt

#let cv-entry-gap() = v(cv-entry-spacing)

// Page-level heading for dedicated CV pages such as projects or competencies.
#let cv-superheading(t) = {
  block(width: 100%, breakable: false, inset: (top: cv-superheading-outer-spacing))[
    #set par(spacing: 0pt)
    #line(length: 100%, stroke: 0.5pt + black)
    #v(5.25pt)
    #align(center, text(size: 17pt, weight: "bold", upper(t)))
    #v(5.25pt)
    #line(length: 100%, stroke: 0.5pt + black)
  ]
}

// Shared renderer for section headings with symmetric outer spacing.
#let cv-section-heading(spacing, t) = block(breakable: false)[
  #v(spacing)
  #set par(spacing: 0pt)
  #text(size: 12pt, weight: "bold", upper(t))
  #v(4.41pt)
  #line(length: 100%, stroke: 0.5pt + black)
  #v(spacing)
]

// Compact section heading for dense CV pages.
#let cv-compact-heading(t) = cv-section-heading(cv-compact-heading-spacing, t)

// Spacious section heading for dedicated project and competency pages.
#let cv-spacious-heading(t) = cv-section-heading(cv-spacious-heading-spacing, t)

// Keep named CV variants honest: a fourpager must render exactly four pages.
#let assert-page-count(expected) = context {
  let actual = counter(page).final().first()
  assert(actual == expected, message: "CV rendered " + str(actual) + " pages; expected " + str(expected))
}

#let document-style(locale: "en-ch", doc) = {
  let locale-parts = locale.split("-")
  assert(locale-parts.len() == 2, message: "locale must contain language and region subtags")
  set page(paper: "a4", margin: (top: 12mm, bottom: 12mm, left: 15mm, right: 15mm))
  set text(
    font: "Archivo",
    size: 10.5pt,
    fill: black,
    lang: locale-parts.first(),
    region: locale-parts.last(),
    top-edge: "cap-height",
    bottom-edge: "baseline",
  )
  set par(leading: 0.7em, justify: false, spacing: 0pt)
  set block(above: 0pt, below: 0pt)
  show link: it => text(fill: rgb("#1e3a5f"), it)
  doc
}
