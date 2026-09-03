#import "../../shared/styles/document.typ": document-style
#import "../../shared/components/cover-letter.typ": cover-letter
#show: document-style.with(locale: "de-ch")

#let application-path = sys.inputs.at("application", default: "/showcase/de-ch/application.json")
#let application = json(application-path)

#cover-letter(
  "de-CH",
  application,
  signature-path: "/cvl/cl/assets/signature.png",
)
