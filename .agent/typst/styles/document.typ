// Shared page setup for CVs and cover letters. Element styles and the
// letterhead live visibly in each cvl/<locale> document; measurement
// primitives live in line-contract.typ.
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
