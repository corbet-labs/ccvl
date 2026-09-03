// Shared renderer for the measured five-paragraph, five-highlight cover-letter contract.
#import "../application.typ": cover-letter-contract, validate-application
#import "../line-contract.typ": line-contract-mode, measured-line, measured-lines
#import "../profile.typ": profile
#import "header.typ": application-header

#let cover-letter(locale, application, signature-path: none) = {
  validate-application(application, expected-language: locale, require-cl: true)
  let job = application.job
  let letter = application.tailored_cl
  let recipient = job.cl_recipient
  let is-german = locale == "de-CH"
  let recipient-lines = (
    recipient.name,
    recipient.title,
    recipient.company,
    recipient.address_line_1,
    recipient.address_line_2,
  ).filter(line => line.trim() != "")
  let subject = if is-german {
    if job.organization.trim() == "" {
      [Offene Bewerbung | #job.title]
    } else {
      [Bewerbung als #job.title]
    }
  } else if job.organization.trim() == "" {
    [Open Application | #job.title]
  } else {
    [Application for #job.title]
  }
  let salutation = if recipient.name.trim() != "" {
    if is-german { [Guten Tag #recipient.name,] } else { [Dear #recipient.name,] }
  } else if is-german {
    [Guten Tag,]
  } else {
    [Dear Hiring Team,]
  }
  let closing = if is-german { [Freundliche Grüsse] } else { [Yours sincerely,] }

  let paragraph(index) = block(breakable: false)[
    #measured-lines(
      "cl.paragraph." + str(index + 1),
      "cl-body",
      letter.paragraphs.at(index).lines,
    )
  ]
  let highlights = block(
    fill: rgb("#f8fafc"),
    stroke: (left: 2.5pt + rgb("#1e3a5f")),
    inset: 8pt,
    radius: 2pt,
    width: 100%,
  )[
    #for index in range(5) {
      grid(
        columns: (6mm, 1fr),
        [#text(weight: "bold", fill: rgb("#1e3a5f"))[#(index + 1)]],
        [#measured-line("cl.highlight." + str(index + 1), "cl-highlight", letter.highlights.at(index))],
      )
      if index < 4 { v(5.25pt) }
    }
  ]
  let header-content = [
    #application-header(locale: if is-german { "de-ch" } else { "en-ch" })
  ]
  let subject-content = [
    #grid(
      columns: (1fr, auto),
      align: (left, right),
      text(size: 12pt, weight: "bold", subject), text(size: 10.5pt, job.application_date),
    )
    #v(4.41pt)
    #line(length: 100%, stroke: 0.5pt + black)
    #if recipient-lines.len() > 0 {
      v(13.125pt)
      align(right)[#recipient-lines.join(linebreak())]
    }
  ]
  let salutation-content = [#salutation]
  let closing-content = block(breakable: false)[
    #closing
    #v(5.25pt)
    #if signature-path != none {
      image(signature-path, height: 31.5pt)
      v(2pt)
    }
    #profile.name
  ]

  layout(size => {
    let content-blocks = (
      header-content,
      subject-content,
      salutation-content,
      paragraph(0),
      paragraph(1),
      paragraph(2),
      highlights,
      paragraph(3),
      paragraph(4),
      closing-content,
    )
    let heights = content-blocks.map(item => measure(item, width: size.width).height)
    let fixed-height = heights.fold(0pt, (total, height) => total + height)
    let gap-count = content-blocks.len() - 1
    let gap-height = (size.height - fixed-height) / gap-count
    let highlight-top = heights.slice(0, 6).fold(0pt, (total, height) => total + height) + 6 * gap-height
    let highlight-center = 100 * (highlight-top + heights.at(6) / 2) / size.height
    let rhythm = cover-letter-contract.vertical_rhythm
    let metrics = (
      (
        id: "cl.vertical-gap",
        kind: "cl-vertical-gap",
        text: "equal distributed gap between cover-letter content blocks",
        actual_fill: calc.round(10 * gap-height / 1pt) / 10,
        min_fill: rhythm.gap_pt.minimum,
        target_fill: rhythm.gap_pt.target,
        max_fill: rhythm.gap_pt.maximum,
        unit: "pt",
      ),
      (
        id: "cl.highlight-center",
        kind: "cl-highlight-center",
        text: "vertical centre of the highlight block",
        actual_fill: calc.round(10 * highlight-center) / 10,
        min_fill: rhythm.highlight_center_percent.minimum,
        target_fill: rhythm.highlight_center_percent.target,
        max_fill: rhythm.highlight_center_percent.maximum,
        unit: "%",
      ),
    )
    if line-contract-mode == "enforce" {
      for metric in metrics {
        assert(
          metric.actual_fill >= metric.min_fill and metric.actual_fill <= metric.max_fill,
          message: metric.id
            + " measured "
            + str(metric.actual_fill)
            + metric.unit
            + ", target "
            + str(metric.target_fill)
            + metric.unit
            + ", allowed "
            + str(metric.min_fill)
            + "–"
            + str(metric.max_fill)
            + metric.unit
            + ". Adjust evidenced content or line allocation, then measure again.",
        )
      }
    }
    [
      #for metric in metrics [
        #metadata(metric) <ccvl-layout>
      ]
    ]
    block(width: 100%, height: size.height)[
      #grid(
        columns: (1fr,),
        rows: (
          auto,
          1fr,
          auto,
          1fr,
          auto,
          1fr,
          auto,
          1fr,
          auto,
          1fr,
          auto,
          1fr,
          auto,
          1fr,
          auto,
          1fr,
          auto,
          1fr,
          auto,
        ),
        align: (left, top),
        header-content,
        [],
        subject-content,
        [],
        salutation-content,
        [],
        paragraph(0),
        [],
        paragraph(1),
        [],
        paragraph(2),
        [],
        highlights,
        [],
        paragraph(3),
        [],
        paragraph(4),
        [],
        closing-content,
      )
    ]
  })
}
