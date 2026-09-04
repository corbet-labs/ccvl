// Shared application header backed by canonical profile data.
#import "../profile.typ": localized-profile, profile

#let application-header(locale: "en-ch") = {
  let localized = localized-profile.at(locale)
  let contacts = (
    link("mailto:" + profile.email)[#profile.email],
    if profile.phone-label != none and profile.phone-href != none {
      link(profile.phone-href)[#profile.phone-label]
    },
    profile.location,
    profile.languages,
    localized.nationality-and-permit,
    link(profile.linkedin)[LinkedIn],
    link(profile.website)[Web],
    localized.availability,
  ).filter(item => item != none)

  align(center)[#text(size: 15.75pt, weight: "bold")[#profile.name]]
  v(6.3pt)
  align(center)[
    #text(size: 9.03pt)[
      #contacts.join([ | ])
    ]
  ]
}
