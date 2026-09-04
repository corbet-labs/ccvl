#!/usr/bin/env python3
"""Test deterministic document preset naming."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import render  # noqa: E402


class RenderTests(unittest.TestCase):
    def test_page_counts_have_explicit_preset_names(self) -> None:
        self.assertEqual(render.cv_preset(2), "twopager")
        self.assertEqual(render.cv_preset(3), "threepager")
        self.assertEqual(render.cv_preset(4), "fourpager")
        with self.assertRaises(render.RenderError):
            render.cv_preset(1)
        with self.assertRaises(render.RenderError):
            render.cv_preset(5)


if __name__ == "__main__":
    unittest.main()
