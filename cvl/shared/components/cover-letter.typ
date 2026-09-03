// Shared renderer for the five-paragraph, five-highlight cover-letter contract.
#import "../application.typ": validate-application
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

  application-header(locale: if is-german { "de-ch" } else { "en-ch" })

  v(13.125pt)
  grid(
    columns: (1fr, auto),
    align: (left, right),
    text(size: 12pt, weight: "bold", subject), text(size: 10.5pt, job.application_date),
  )
  v(4.41pt)
  line(length: 100%, stroke: 0.5pt + black)

  if recipient-lines.len() > 0 {
    v(13.125pt)
    align(right)[#recipient-lines.join(linebreak())]
  }

  v(13.125pt)
  block(breakable: false)[
    #set par(justify: true)
    #salutation
  ]

  for index in range(3) {
    v(10.5pt)
    block(breakable: false)[
      #set par(justify: true)
      #letter.paragraphs.at(index)
    ]
  }

  v(10.5pt)
  block(
    fill: rgb("#f8fafc"),
    stroke: (left: 2.5pt + rgb("#1e3a5f")),
    inset: 8pt,
    radius: 2pt,
    width: 100%,
  )[
    #for index in range(5) {
      grid(
        columns: (6mm, 1fr),
        [#text(weight: "bold", fill: rgb("#1e3a5f"))[#(index + 1)]], [#letter.highlights.at(index)],
      )
      if index < 4 { v(5.25pt) }
    }
  ]

  for index in range(3, 5) {
    v(10.5pt)
    block(breakable: false)[
      #set par(justify: true)
      #letter.paragraphs.at(index)
    ]
  }

  v(10.5pt)
  block(breakable: false)[
    #closing
    #v(5.25pt)
    #if signature-path != none {
      image(signature-path, height: 31.5pt)
      v(2pt)
    }
    #profile.name
  ]
}
