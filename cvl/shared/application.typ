// Validation shared by CV and cover-letter renderers.
#let require-fields(value, fields, scope) = {
  for field in fields {
    assert(field in value, message: scope + "." + field + " is required")
  }
}

#let validate-application(
  application,
  expected-language: none,
  require-cv: false,
  require-cl: false,
) = {
  require-fields(
    application,
    ("schema_version", "revision", "job", "tailored_cv", "tailored_cl", "constraints"),
    "application",
  )
  assert(application.schema_version == 1, message: "unsupported application schema version")

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
  if require-cv {
    assert(
      application.tailored_cv.summary.trim() != "",
      message: "application.tailored_cv.summary is required",
    )
  }

  require-fields(
    application.tailored_cl,
    ("paragraphs", "highlights"),
    "application.tailored_cl",
  )
  assert(
    application.tailored_cl.paragraphs.len() == 5,
    message: "application.tailored_cl.paragraphs must contain exactly five items",
  )
  assert(
    application.tailored_cl.highlights.len() == 5,
    message: "application.tailored_cl.highlights must contain exactly five items",
  )
  if require-cl {
    for paragraph in application.tailored_cl.paragraphs {
      assert(paragraph.trim() != "", message: "every cover-letter paragraph is required")
    }
    for highlight in application.tailored_cl.highlights {
      assert(highlight.trim() != "", message: "every cover-letter highlight is required")
    }
  }

  require-fields(
    application.constraints,
    ("cv_summary_max_lines", "cl_paragraph_max_lines", "cl_highlight_max_lines"),
    "application.constraints",
  )
  assert(
    application.constraints.cl_paragraph_max_lines.len() == 5,
    message: "application.constraints.cl_paragraph_max_lines must contain five items",
  )
  assert(
    application.constraints.cl_highlight_max_lines.len() == 5,
    message: "application.constraints.cl_highlight_max_lines must contain five items",
  )
}
