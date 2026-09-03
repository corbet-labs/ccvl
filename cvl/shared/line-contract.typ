// Measured single-line presentation contract shared by every document renderer.
#let line-contract-mode = sys.inputs.at("line-contracts", default: "enforce")
#assert(
  line-contract-mode in ("enforce", "report"),
  message: "line-contracts must be enforce or report",
)

#let measured-content-line(id, kind, body, min-fill, target-fill, max-fill, source-text: none) = layout(size => {
  let measured = measure(body)
  let actual-fill = calc.round(1000 * measured.width / size.width) / 10
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
  [#metadata(metric) <ccvl-line>#box(body)]
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
