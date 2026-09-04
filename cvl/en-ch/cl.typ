#import "/.agent/typst/styles/document.typ": document-style
#import "/.agent/typst/components/cover-letter.typ": cover-letter
#show: document-style.with(locale: "en-ch")

#let application-path = sys.inputs.at("application", default: "/cvl/en-ch/application.json")
#let application = json(application-path)

#cover-letter(
  "en-CH",
  application,
  signature-path: "/cvl/assets/signature.png",
)
