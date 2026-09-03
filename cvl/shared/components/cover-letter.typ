// Shared renderer for the measured five-paragraph, five-highlight cover-letter contract.
#import "../application.typ": validate-application
#import "../line-contract.typ": measured-line, measured-lines
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
  let paragraph-region(indices) = {
    for (position, index) in indices.enumerate() {
      paragraph(index)
      if position < indices.len() - 1 {
        v(8.4pt)
      }
    }
  }
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
  let top-content = [
    #application-header(locale: if is-german { "de-ch" } else { "en-ch" })
    #v(13.125pt)
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
    #v(13.125pt)
    #salutation
    #v(10.5pt)
    #paragraph-region((0, 1, 2))
  ]
  let bottom-content = align(bottom)[
    #paragraph-region((3, 4))
    #v(10.5pt)
    #block(breakable: false)[
      #closing
      #v(5.25pt)
      #if signature-path != none {
        image(signature-path, height: 31.5pt)
        v(2pt)
      }
      #profile.name
    ]
  ]

  layout(size => {
    let half-height = (size.height - measure(highlights, width: size.width).height) / 2
    assert(
      measure(top-content, width: size.width).height <= half-height,
      message: "cover-letter header, recipient, and paragraphs 1–3 exceed their half-page region",
    )
    assert(
      measure(bottom-content, width: size.width).height <= half-height,
      message: "cover-letter paragraphs 4–5 and signature exceed their half-page region",
    )
    block(width: 100%, height: size.height)[
      #grid(
        rows: (1fr, auto, 1fr),
        align: (left, top),
        top-content,
        highlights,
        bottom-content,
      )
    ]
  })
}
