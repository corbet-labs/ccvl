use std::path::Path;

use anyhow::{Context, Result, ensure};
use lopdf::{Dictionary, Document, Object, ObjectId};
use regex::Regex;

pub struct VerifiedPdf {
    document: Document,
}

impl VerifiedPdf {
    pub fn page_content(&self, page: u32) -> Result<Vec<u8>> {
        let id = self
            .document
            .get_pages()
            .get(&page)
            .copied()
            .context("PDF page is missing")?;
        Ok(self.document.get_page_content(id))
    }
}

pub fn verify(
    path: &Path,
    expected_pages: usize,
    contacts: &[String],
    require_image: bool,
) -> Result<VerifiedPdf> {
    let document =
        Document::load(path).with_context(|| format!("cannot parse {}", path.display()))?;
    ensure!(
        !document.trailer.has(b"Encrypt"),
        "{} is encrypted",
        path.display()
    );
    let pages = document.get_pages();
    ensure!(
        pages.len() == expected_pages,
        "{} rendered {} pages; expected {expected_pages}",
        path.display(),
        pages.len()
    );
    let catalog_id = document.trailer.get(b"Root")?.as_reference()?;
    let catalog = document.get_dictionary(catalog_id)?;
    for key in [b"AcroForm".as_slice(), b"OpenAction", b"AA"] {
        ensure!(
            !catalog.has(key),
            "{} contains forbidden catalog entry /{}",
            path.display(),
            String::from_utf8_lossy(key)
        );
    }
    if let Some(names) = get_dict(&document, catalog, b"Names") {
        ensure!(
            !names.has(b"JavaScript") && !names.has(b"EmbeddedFiles"),
            "{} contains JavaScript or embedded files",
            path.display()
        );
    }

    let font_pattern = Regex::new(r"^[A-Z]{6}\+Archivo-(Bold|Italic|Medium|Regular)$")?;
    let mut fonts_seen = 0;
    for (page_number, page_id) in &pages {
        let page = document.get_dictionary(*page_id)?;
        ensure!(
            !page.has(b"AA"),
            "{} page {page_number} contains an automatic action",
            path.display()
        );
        let media = inherited(&document, *page_id, b"MediaBox")
            .context("PDF page has no MediaBox")?
            .as_array()?;
        ensure!(
            media.len() == 4,
            "{} page {page_number} has an invalid MediaBox",
            path.display()
        );
        let width = media[2].as_float()? - media[0].as_float()?;
        let height = media[3].as_float()? - media[1].as_float()?;
        ensure!(
            (width - 595.2756).abs() <= 0.2 && (height - 841.8898).abs() <= 0.2,
            "{} page {page_number} is not A4 ({width}×{height})",
            path.display()
        );
        for font in document.get_page_fonts(*page_id)?.values() {
            fonts_seen += 1;
            let base = font.get(b"BaseFont")?.as_name()?;
            let base = String::from_utf8_lossy(base);
            ensure!(
                font_pattern.is_match(&base),
                "{} contains a fallback or unsubsetted font: {base}",
                path.display()
            );
            ensure!(
                font.has(b"ToUnicode"),
                "{} contains a font without a Unicode map: {base}",
                path.display()
            );
        }
    }
    ensure!(fonts_seen > 0, "{} contains no fonts", path.display());
    let has_embedded_font = document.objects.values().any(|object| {
        object_dictionary(object).is_some_and(|dictionary| {
            dictionary.has(b"FontFile")
                || dictionary.has(b"FontFile2")
                || dictionary.has(b"FontFile3")
        })
    });
    ensure!(
        has_embedded_font,
        "{} contains no embedded font program",
        path.display()
    );
    if require_image {
        let has_image = document.objects.values().any(|object| {
            object_dictionary(object)
                .and_then(|dictionary| dictionary.get(b"Subtype").ok())
                .and_then(|value| value.as_name().ok())
                == Some(b"Image")
        });
        ensure!(
            has_image,
            "{} is missing its rendered signature image",
            path.display()
        );
    }
    let page_numbers = pages.keys().copied().collect::<Vec<_>>();
    let text = document
        .extract_text(&page_numbers)
        .context("PDF text extraction failed")?;
    ensure!(
        text.chars().filter(|item| !item.is_whitespace()).count() >= 100,
        "{} has no usable text layer",
        path.display()
    );
    for contact in contacts {
        ensure!(
            text.contains(contact),
            "{} is missing machine-readable contact text: {contact}",
            path.display()
        );
    }
    Ok(VerifiedPdf { document })
}

fn object_dictionary(object: &Object) -> Option<&Dictionary> {
    match object {
        Object::Dictionary(dictionary) => Some(dictionary),
        Object::Stream(stream) => Some(&stream.dict),
        _ => None,
    }
}

fn get_dict<'a>(
    document: &'a Document,
    parent: &'a Dictionary,
    key: &[u8],
) -> Option<&'a Dictionary> {
    match parent.get(key).ok()? {
        Object::Dictionary(dictionary) => Some(dictionary),
        Object::Reference(id) => document.get_dictionary(*id).ok(),
        _ => None,
    }
}

fn inherited<'a>(document: &'a Document, mut id: ObjectId, key: &[u8]) -> Option<&'a Object> {
    loop {
        let dictionary = document.get_dictionary(id).ok()?;
        if let Ok(value) = dictionary.get(key) {
            return Some(value);
        }
        id = dictionary.get(b"Parent").ok()?.as_reference().ok()?;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_pdf_is_rejected() {
        assert!(verify(Path::new("definitely-missing.pdf"), 1, &[], false).is_err());
    }
}
