#!/usr/bin/env python3
"""Test cross-engine PDF comparison without invoking a compiler."""

from __future__ import annotations

import re
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import check  # noqa: E402


class PdfEquivalenceTests(unittest.TestCase):
    def test_rendition_identifier_is_not_document_content(self) -> None:
        original = ROOT / "cvl" / "cv" / "output" / "de-ch" / "2pager" / "cv.pdf"
        changed = re.sub(
            rb"(<xmpMM:InstanceID>)[^<]*(</xmpMM:InstanceID>)",
            rb"\1AAAAAAAAAAAAAAAAAAAAAA==\2",
            original.read_bytes(),
        )
        changed = re.sub(
            rb"(/ID\[\([^)]*\)\()[^)]*(\)\]\s*>>)",
            rb"\1AAAAAAAAAAAAAAAAAAAAAA==\2",
            changed,
        )
        self.assertNotEqual(original.read_bytes(), changed)
        with tempfile.TemporaryDirectory(prefix="ccvl-pdf-equivalence-") as directory:
            equivalent = Path(directory) / "equivalent.pdf"
            equivalent.write_bytes(changed)
            self.assertEqual(check.semantic_pdf_signature(original), check.semantic_pdf_signature(equivalent))

    def test_metadata_change_is_detected(self) -> None:
        original = ROOT / "cvl" / "cv" / "output" / "de-ch" / "2pager" / "cv.pdf"
        changed = original.read_bytes().replace(b"<dc:language>", b"<dc:languagf>", 1)
        self.assertNotEqual(original.read_bytes(), changed)
        with tempfile.TemporaryDirectory(prefix="ccvl-pdf-equivalence-") as directory:
            modified = Path(directory) / "modified.pdf"
            modified.write_bytes(changed)
            self.assertNotEqual(check.semantic_pdf_signature(original), check.semantic_pdf_signature(modified))


if __name__ == "__main__":
    unittest.main()
