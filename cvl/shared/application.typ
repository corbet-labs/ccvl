// Validation shared by CV and cover-letter renderers.
#let workspace = json("/ccvl.json")
#let cover-letter-contract = workspace.documents.cover_letter

#let require-fields(value, fields, scope) = {
  for field in fields {
    assert(field in value, message: scope + "." + field + " is required")
  }
}

#let validate-line-contract(line, scope, require-text: true) = {
  require-fields(line, ("text", "min_fill", "target_fill", "max_fill"), scope)
  if require-text {
    assert(line.text.trim() != "", message: scope + ".text is required")
  }
  assert(
    line.min_fill <= line.target_fill and line.target_fill <= line.max_fill,
    message: scope + " must satisfy min_fill <= target_fill <= max_fill",
  )
  assert(line.min_fill >= 1 and line.max_fill <= 100, message: scope + " fill bounds must be within 1–100%")
}

#let line-count(paragraphs) = paragraphs.fold(0, (total, paragraph) => total + paragraph.lines.len())

#let validate-application(
  application,
  expected-language: none,
  require-cv: false,
  require-cl: false,
) = {
  require-fields(application, ("schema_version", "revision", "job", "tailored_cv", "tailored_cl"), "application")
  assert(application.schema_version == 2, message: "unsupported application schema version")

  require-fields(
    application.job,
    (
      "id",
      "title",
      "organization",
      "location",
      "source",
      "url",
      "language",
      "application_date",
      "description",
      "connections",
      "company_context",
      "notes",
      "cl_recipient",
    ),
    "application.job",
  )
  assert(application.job.id.trim() != "", message: "application.job.id is required")
  if expected-language != none {
    assert(
      application.job.language == expected-language,
      message: "application language must be " + expected-language,
    )
  }

  require-fields(application.tailored_cv, ("summary",), "application.tailored_cv")
  assert(
    application.tailored_cv.summary.len() == 5,
    message: "application.tailored_cv.summary must contain exactly five rendered lines",
  )
  for (index, line) in application.tailored_cv.summary.enumerate() {
    validate-line-contract(line, "application.tailored_cv.summary." + str(index + 1), require-text: require-cv)
  }

  require-fields(application.tailored_cl, ("paragraphs", "highlights"), "application.tailored_cl")
  let paragraphs = application.tailored_cl.paragraphs
  assert(
    paragraphs.len() == cover-letter-contract.paragraphs,
    message: "application.tailored_cl.paragraphs must contain exactly "
      + str(cover-letter-contract.paragraphs)
      + " items",
  )
  let body-lines = line-count(paragraphs)
  let body-contract = cover-letter-contract.body_lines
  assert(
    body-lines >= body-contract.minimum and body-lines <= body-contract.maximum,
    message: "cover-letter body must contain "
      + str(body-contract.minimum)
      + "–"
      + str(body-contract.maximum)
      + " rendered lines",
  )
  for region in cover-letter-contract.line_regions {
    let start = region.paragraphs.first() - 1
    let end = region.paragraphs.last()
    let region-lines = line-count(paragraphs.slice(start, end))
    assert(
      region-lines >= region.minimum and region-lines <= region.maximum,
      message: "cover-letter paragraphs "
        + str(region.paragraphs.first())
        + "–"
        + str(region.paragraphs.last())
        + " must contain "
        + str(region.minimum)
        + "–"
        + str(region.maximum)
        + " rendered lines",
    )
  }
  for (paragraph-index, paragraph) in paragraphs.enumerate() {
    require-fields(paragraph, ("lines",), "application.tailored_cl.paragraphs." + str(paragraph-index + 1))
    assert(paragraph.lines.len() > 0, message: "every cover-letter paragraph needs at least one rendered line")
    for (line-index, line) in paragraph.lines.enumerate() {
      validate-line-contract(
        line,
        "application.tailored_cl.paragraphs." + str(paragraph-index + 1) + ".lines." + str(line-index + 1),
        require-text: require-cl,
      )
    }
  }
  assert(
    application.tailored_cl.highlights.len() == cover-letter-contract.highlights,
    message: "application.tailored_cl.highlights must contain exactly "
      + str(cover-letter-contract.highlights)
      + " one-line items",
  )
  for (index, line) in application.tailored_cl.highlights.enumerate() {
    validate-line-contract(line, "application.tailored_cl.highlights." + str(index + 1), require-text: require-cl)
  }
}
