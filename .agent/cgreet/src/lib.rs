//! Deterministic locale-correct greeting and salutation helpers.
//!
//! `cgreet` owns every salutation rule: which honorifics and academic titles
//! render, how the surname is found, and which regions punctuate the German
//! salutation with a comma. The Typst renderer mirrors this logic in
//! `.agent/typst/application.typ` (Typst cannot depend on a Rust crate);
//! `ccvl` consumes this crate for validation warnings and checks.
//!
//! Rules are sourced from the national correspondence norms (SN 010130 for
//! ch/li, DIN 5008 for de/at; at follows DIN since ÖNORM A 1080 was withdrawn
//! in 2018). Same input always yields the same output: no models, no I/O.

/// German correspondence region. Only lowercase codes: ch, li, de, at.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Region {
    /// Switzerland (SN 010130): no comma after the salutation.
    Ch,
    /// Liechtenstein (renders Swiss-style): no comma after the salutation.
    Li,
    /// Germany (DIN 5008): trailing comma after the salutation.
    De,
    /// Austria (DIN-oriented): trailing comma after the salutation.
    At,
}

impl Region {
    /// Parse a lowercase region code. Returns `None` for anything else.
    #[must_use]
    pub fn parse(code: &str) -> Option<Self> {
        match code {
            "ch" => Some(Self::Ch),
            "li" => Some(Self::Li),
            "de" => Some(Self::De),
            "at" => Some(Self::At),
            _ => None,
        }
    }

    /// Whether the salutation carries a trailing comma (de/at only).
    #[must_use]
    pub fn uses_comma(self) -> bool {
        matches!(self, Self::De | Self::At)
    }
}

/// Last whitespace-separated token of a recipient name for the salutation.
/// "Dr. Jane Doe" -> "Doe"; single-token and hyphenated names survive;
/// empty/whitespace yields "" for the generic greeting.
#[must_use]
pub fn salutation_last_name(name: &str) -> &str {
    name.split_whitespace().next_back().unwrap_or("")
}

/// Honorific of a recipient name for the German salutation: "frau" for
/// "Frau", "herr" for "Herr"/"Herrn", "" when unparsable. Abbreviations
/// ("Hr.", "Fr.") are rejected: the Anrede always uses "Herr" (never the
/// accusative "Herrn", which belongs only in the postal address) and never
/// abbreviates "Frau".
#[must_use]
pub fn salutation_honorific(name: &str) -> &'static str {
    match name
        .split_whitespace()
        .next()
        .unwrap_or("")
        .trim_matches('.')
        .to_ascii_lowercase()
        .as_str()
    {
        "frau" => "frau",
        "herr" | "herrn" => "herr",
        _ => "",
    }
}

/// Academic titles preserved in the German salutation: "Dr." stays
/// abbreviated, "Prof." normalises to the spelled-out "Professor",
/// "Dipl.-Ing." and "Mag." survive. Protocol keeps only the highest title,
/// so Professor suppresses Dr.
#[must_use]
pub fn salutation_titles(name: &str) -> Vec<&'static str> {
    let mut kept: Vec<&'static str> = Vec::new();
    for token in name.split_whitespace() {
        let core = token.trim_matches('.').to_ascii_lowercase();
        let title = match core.as_str() {
            "dr" => "Dr.",
            "prof" | "professor" => "Professor",
            "dipl-ing" | "dipling" => "Dipl.-Ing.",
            "mag" | "magister" => "Mag.",
            _ => continue,
        };
        if !kept.contains(&title) {
            kept.push(title);
        }
    }
    if kept.contains(&"Professor") {
        vec!["Professor"]
    } else {
        kept
    }
}

fn is_salutation_filler(token: &str) -> bool {
    matches!(
        token.trim_matches('.').to_ascii_lowercase().as_str(),
        "herr"
            | "herrn"
            | "frau"
            | "mr"
            | "mrs"
            | "ms"
            | "miss"
            | "dr"
            | "prof"
            | "professor"
            | "dipl-ing"
            | "dipling"
            | "mag"
            | "magister"
            | "phd"
            | "ma"
            | "ba"
            | "bsc"
            | "msc"
    )
}

/// Surname for the German salutation: last significant token after dropping
/// the honorific, academic titles, and post-nominal grades.
#[must_use]
pub fn salutation_surname(name: &str) -> &str {
    name.split_whitespace()
        .rfind(|token| !is_salutation_filler(token))
        .unwrap_or("")
}

/// Locale-correct German salutation. Without a parsable honorific or surname
/// it falls back to the generic "Sehr geehrte Damen und Herren" so the letter
/// stays formally safe.
#[must_use]
pub fn de_salutation(name: &str, region: Region) -> String {
    let punct = if region.uses_comma() { "," } else { "" };
    let honorific = salutation_honorific(name);
    let surname = salutation_surname(name);
    if honorific.is_empty() || surname.is_empty() {
        return format!("Sehr geehrte Damen und Herren{punct}");
    }
    let titles = salutation_titles(name);
    let title_part = if titles.is_empty() {
        String::new()
    } else {
        format!(" {}", titles.join(" "))
    };
    if honorific == "frau" {
        format!("Sehr geehrte Frau{title_part} {surname}{punct}")
    } else {
        format!("Sehr geehrter Herr{title_part} {surname}{punct}")
    }
}

/// Non-blocking advisory when the recipient name is missing: the letter
/// still renders with the generic salutation, but a tailored opportunity
/// should name a person. Returns `None` when a last name is available.
#[must_use]
pub fn recipient_salutation_warning(location: &str, name: &str) -> Option<String> {
    if salutation_last_name(name).is_empty() {
        Some(format!(
            "{location}: job.cl_recipient.name is empty; using generic salutation (provide a name for tailored opportunities)"
        ))
    } else {
        None
    }
}

/// Non-blocking advisory for German records whose recipient name carries no
/// parsable Herr/Frau honorific: the letter falls back to the generic
/// salutation, so a human should supply the full address form (e.g.
/// "Frau Dr. Müller"). Returns `None` for empty names (already covered by
/// [`recipient_salutation_warning`]) and for complete names.
#[must_use]
pub fn de_honorific_warning(location: &str, name: &str) -> Option<String> {
    if salutation_last_name(name).is_empty() {
        return None;
    }
    if salutation_honorific(name).is_empty() || salutation_surname(name).is_empty() {
        Some(format!(
            "{location}: job.cl_recipient.name has no parsable Herr/Frau honorific; using generic salutation (provide e.g. \"Frau Dr. Müller\" for tailored opportunities)"
        ))
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn regions_parse_lowercase_codes_and_own_the_comma() {
        assert_eq!(Region::parse("ch"), Some(Region::Ch));
        assert_eq!(Region::parse("li"), Some(Region::Li));
        assert_eq!(Region::parse("de"), Some(Region::De));
        assert_eq!(Region::parse("at"), Some(Region::At));
        assert_eq!(Region::parse("CH"), None);
        assert_eq!(Region::parse("fr"), None);
        assert_eq!(Region::parse(""), None);
        assert!(!Region::Ch.uses_comma());
        assert!(!Region::Li.uses_comma());
        assert!(Region::De.uses_comma());
        assert!(Region::At.uses_comma());
    }

    #[test]
    fn salutation_uses_only_the_last_name_token() {
        for (input, expected) in [
            ("Dr. Jane Doe", "Doe"),
            ("Ms Test Person", "Person"),
            ("Madonna", "Madonna"),
            ("Anne-Marie Müller-Schmidt", "Müller-Schmidt"),
            ("  Jane   Doe  ", "Doe"),
            ("Jane\tDoe", "Doe"),
            ("", ""),
            ("   ", ""),
            ("\t\n ", ""),
        ] {
            assert_eq!(salutation_last_name(input), expected, "input: {input:?}");
        }
    }

    #[test]
    fn german_salutation_parses_honorific_titles_and_punctuation() {
        // ch/li (SN 010130): no comma. de/at (DIN 5008): trailing comma.
        for (input, ch, de) in [
            (
                "Frau Müller",
                "Sehr geehrte Frau Müller",
                "Sehr geehrte Frau Müller,",
            ),
            (
                "Herr Müller",
                "Sehr geehrter Herr Müller",
                "Sehr geehrter Herr Müller,",
            ),
            (
                "Frau Dr. Müller",
                "Sehr geehrte Frau Dr. Müller",
                "Sehr geehrte Frau Dr. Müller,",
            ),
            (
                "Herr Prof. Dr. Müller",
                "Sehr geehrter Herr Professor Müller",
                "Sehr geehrter Herr Professor Müller,",
            ),
            (
                "Herrn Müller",
                "Sehr geehrter Herr Müller",
                "Sehr geehrter Herr Müller,",
            ),
            (
                "frau müller",
                "Sehr geehrte Frau müller",
                "Sehr geehrte Frau müller,",
            ),
            (
                "Frau Anne-Marie Müller-Schmidt",
                "Sehr geehrte Frau Müller-Schmidt",
                "Sehr geehrte Frau Müller-Schmidt,",
            ),
        ] {
            assert_eq!(de_salutation(input, Region::Ch), ch, "input: {input:?}");
            assert_eq!(de_salutation(input, Region::De), de, "input: {input:?}");
        }
        assert_eq!(
            de_salutation("Frau Müller", Region::Li),
            "Sehr geehrte Frau Müller"
        );
        assert_eq!(
            de_salutation("Herr Müller", Region::At),
            "Sehr geehrter Herr Müller,"
        );
        // Missing honorific, surname, or name: formally safe generic fallback.
        for input in [
            "",
            "   ",
            "Jane Doe",
            "Dr. Jane Doe",
            "Hr. Müller",
            "Fr. Müller",
            "Herr Dr.",
        ] {
            assert_eq!(
                de_salutation(input, Region::Ch),
                "Sehr geehrte Damen und Herren",
                "input: {input:?}"
            );
            assert_eq!(
                de_salutation(input, Region::De),
                "Sehr geehrte Damen und Herren,",
                "input: {input:?}"
            );
        }
    }

    #[test]
    fn german_honorific_parsing_rejects_abbreviations() {
        assert_eq!(salutation_honorific("Frau Müller"), "frau");
        assert_eq!(salutation_honorific("Herr Müller"), "herr");
        assert_eq!(salutation_honorific("Herrn Müller"), "herr");
        assert_eq!(salutation_honorific("Hr. Müller"), "");
        assert_eq!(salutation_honorific("Fr. Müller"), "");
        assert_eq!(salutation_honorific("Jane Doe"), "");
        assert_eq!(salutation_honorific(""), "");
        assert_eq!(salutation_surname("Frau Dr. Müller"), "Müller");
        assert_eq!(salutation_surname("Herr Dr."), "");
        assert_eq!(
            salutation_titles("Herr Prof. Dr. Müller"),
            vec!["Professor"]
        );
        assert_eq!(salutation_titles("Frau Dr. Müller"), vec!["Dr."]);
        assert_eq!(salutation_titles("Herr Mag. Müller"), vec!["Mag."]);
    }

    #[test]
    fn german_name_without_honorific_warns_for_a_human() {
        assert!(de_honorific_warning("fixture", "Frau Müller").is_none());
        assert!(de_honorific_warning("fixture", "Herr Dr. Müller").is_none());
        // Empty names are covered by recipient_salutation_warning, not here.
        assert!(de_honorific_warning("fixture", "").is_none());
        assert!(de_honorific_warning("fixture", "   ").is_none());
        let warning = de_honorific_warning("fixture", "Jane Doe")
            .expect("honorific-free German name must warn");
        assert!(warning.contains("Herr/Frau"));
        assert!(warning.contains("generic salutation"));
    }

    #[test]
    fn missing_recipient_name_warns() {
        let warning =
            recipient_salutation_warning("fixture", "").expect("empty recipient must warn");
        assert!(warning.contains("job.cl_recipient.name is empty"));
        assert!(warning.contains("generic salutation"));
        assert!(recipient_salutation_warning("fixture", "Dr. Jane Doe").is_none());
        assert!(recipient_salutation_warning("fixture", "   ").is_some());
    }
}
