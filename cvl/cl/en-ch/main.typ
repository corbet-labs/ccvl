#import "../../shared/styles/document.typ": document-style
#import "../../shared/components/cover-letter.typ": cover-letter
#show: document-style.with(locale: "en-ch")

#let application-path = sys.inputs.at("application", default: "/cvl/general/en-ch/application.json")
#let application = json(application-path)

#cover-letter(
  "en-CH",
  application,
  signature-path: "/cvl/cl/assets/signature.png",
)
