// Measured single-line presentation contract shared by every document renderer.
#let line-contract-mode = sys.inputs.at("line-contracts", default: "enforce")
#assert(
  line-contract-mode in ("enforce", "report"),
  message: "line-contracts must be enforce or report",
)

#let line-contract-marker(
  id,
  kind,
  body,
  min-fill,
  target-fill,
  max-fill,
  available-width,
  source-text: none,
) = {
  let measured = measure(body)
  let actual-fill = calc.round(1000 * measured.width / available-width) / 10
  let metric = (
    id: id,
    kind: kind,
    text: if source-text == none { repr(body) } else { source-text },
    actual_fill: actual-fill,
    min_fill: min-fill,
    target_fill: target-fill,
    max_fill: max-fill,
  )
  if line-contract-mode == "enforce" {
    let guidance = " Rewrite with relevant, verified signal; then run the line measurement again."
    assert(
      actual-fill >= min-fill,
      message: id
        + " is too short: measured "
        + str(actual-fill)
        + "%, target "
        + str(target-fill)
        + "%, allowed "
        + str(min-fill)
        + "–"
        + str(max-fill)
        + "%."
        + guidance,
    )
    assert(
      actual-fill <= max-fill,
      message: id
        + " is too long: measured "
        + str(actual-fill)
        + "%, target "
        + str(target-fill)
        + "%, allowed "
        + str(min-fill)
        + "–"
        + str(max-fill)
        + "%."
        + guidance,
    )
  }
  [#metadata(metric) <ccvl-line>]
}

#let measured-content-line(
  id,
  kind,
  body,
  min-fill,
  target-fill,
  max-fill,
  source-text: none,
) = layout(size => {
  [
    #line-contract-marker(
      id,
      kind,
      body,
      min-fill,
      target-fill,
      max-fill,
      size.width,
      source-text: source-text,
    )
    #box(body)
  ]
})

#let measured-line(id, kind, contract) = measured-content-line(
  id,
  kind,
  text(contract.text),
  contract.min_fill,
  contract.target_fill,
  contract.max_fill,
  source-text: contract.text,
)

#let measured-lines(id, kind, lines) = {
  for (index, line) in lines.enumerate() {
    measured-line(id + "." + str(index + 1), kind, line)
    if index < lines.len() - 1 {
      linebreak()
    }
  }
}

// Wrap flowing text into exactly `count` lines at the current style.
// Hyphenation must be off at the call site so breaks happen only at spaces,
// which is exactly what this greedy pass replicates with measured widths.
// The caller renders the returned lines explicitly (e.g. measured-lines),
// so no second breaking pass can move the breaks.
#let wrap-exact(text, width, count, scope) = {
  let words = text.replace(regex("\s+"), " ").trim().split(" ")
  let lines = ()
  let current = ""
  for word in words {
    let trial = if current == "" { word } else { current + " " + word }
    if measure(box(trial)).width <= width {
      current = trial
    } else {
      assert(current != "", message: scope + ": word does not fit the line: " + word)
      lines.push(current)
      current = word
    }
  }
  if current != "" {
    lines.push(current)
  }
  assert(
    lines.len() == count,
    message: scope
      + " renders to "
      + str(lines.len())
      + " lines; want exactly "
      + str(count)
      + ". Rewrite with relevant, verified signal—not filler—until it fits.",
  )
  lines
}

// Render explicit lines as one justified paragraph while measuring their natural widths.
// Manual line breaks and the caller's unbreakable block prevent widows and orphans.
#let measured-paragraph(id, kind, lines, justify: true) = layout(size => {
  [
    #for (index, line) in lines.enumerate() {
      line-contract-marker(
        id + "." + str(index + 1),
        kind,
        text(line.text),
        line.min_fill,
        line.target_fill,
        line.max_fill,
        size.width,
        source-text: line.text,
      )
    }
    #set par(justify: justify)
    #for (index, line) in lines.enumerate() {
      text(line.text)
      if index < lines.len() - 1 {
        linebreak()
      }
    }
  ]
})
