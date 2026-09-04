#!/usr/bin/env python3
"""Protect the human-readable ccvl workspace and keyed opportunity paths."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import render  # noqa: E402
import opportunity  # noqa: E402


class WorkspaceLayoutTests(unittest.TestCase):
    def test_three_working_groups_are_top_level_and_documented(self) -> None:
        for name in ("cvl", "targets", "opportunities"):
            with self.subTest(name=name):
                self.assertTrue((ROOT / name).is_dir())
                self.assertTrue((ROOT / name / "README.md").is_file())

    def test_manifest_names_the_general_cvl_and_opportunity_contract(self) -> None:
        manifest = json.loads((ROOT / "ccvl.json").read_text(encoding="utf-8"))
        groups = manifest["workspace_groups"]
        self.assertEqual(list(groups), ["cvl", "targets", "opportunities"])
        self.assertEqual(groups["cvl"]["profile"], "cvl/general/profile.json")
        self.assertEqual(groups["cvl"]["stations"], "cvl/general/stations.json")
        self.assertEqual(groups["opportunities"]["path"], "opportunities/<organisation-key>/<position-key>")
        self.assertEqual(groups["opportunities"]["record"], "application.json")
        self.assertEqual(groups["opportunities"]["output"], "output")

    def test_cv_preset_directories_use_spelled_out_names_only(self) -> None:
        expected = {"twopager", "threepager", "fourpager"}
        output_root = ROOT / "cvl" / "cv" / "output"
        for locale in ("de-ch", "en-ch"):
            with self.subTest(locale=locale):
                actual = {path.name for path in (output_root / locale).iterdir() if path.is_dir()}
                self.assertEqual(actual, expected)
                for preset in expected:
                    self.assertTrue((output_root / locale / preset / "cv.pdf").is_file())

    def test_opportunity_keys_resolve_to_one_canonical_record(self) -> None:
        expected = ROOT / "opportunities" / "acme" / "strategy-lead" / "application.json"
        self.assertEqual(opportunity.record_path("acme", "strategy-lead", require_exists=False), expected)
        for organisation, position in (("../acme", "lead"), ("ACME", "lead"), ("acme", "lead/../other")):
            with self.subTest(organisation=organisation, position=position):
                with self.assertRaises(opportunity.OpportunityError):
                    opportunity.record_path(organisation, position, require_exists=False)

    def test_opportunity_record_selects_its_own_locale_pages_and_documents(self) -> None:
        document = json.loads((ROOT / "cvl/general/en-ch/application.json").read_text(encoding="utf-8"))
        document["job"]["language"] = "en-CH"
        document["tailored_cv"]["pages"] = 3
        document["tailored_cl"] = {"enabled": False}
        with tempfile.TemporaryDirectory(dir=ROOT, prefix=".ccvl-opportunity-test-") as directory:
            opportunity_root = Path(directory)
            record = opportunity_root / "acme" / "strategy-lead" / "application.json"
            record.parent.mkdir(parents=True)
            record.write_text(json.dumps(document), encoding="utf-8")
            stale_cover_letter = record.parent / "output" / "cl.pdf"
            stale_cover_letter.parent.mkdir()
            stale_cover_letter.write_bytes(b"stale")
            with (
                patch.object(opportunity, "OPPORTUNITIES_ROOT", opportunity_root),
                patch.object(render, "render_cv", return_value=record.parent / "output/cv.pdf") as render_cv,
                patch.object(render, "render_cl", return_value=record.parent / "output/cl.pdf") as render_cl,
            ):
                outputs = render.render_opportunity("acme", "strategy-lead")
                self.assertFalse(stale_cover_letter.exists())
        self.assertEqual(outputs, [record.parent / "output/cv.pdf"])
        render_cv.assert_called_once()
        self.assertEqual(render_cv.call_args.args[:2], ("en-ch", 3))
        render_cl.assert_not_called()

    def test_new_opportunity_is_keyed_and_never_overwritten(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT, prefix=".ccvl-new-opportunity-") as directory:
            opportunity_root = Path(directory)
            with patch.object(opportunity, "OPPORTUNITIES_ROOT", opportunity_root):
                record = opportunity.create_record("example_org", "strategy-lead")
                document = json.loads(record.read_text(encoding="utf-8"))
                self.assertEqual(document["job"]["id"], "example_org--strategy-lead")
                with self.assertRaisesRegex(opportunity.OpportunityError, "refusing to overwrite"):
                    opportunity.create_record("example_org", "strategy-lead")


if __name__ == "__main__":
    unittest.main()
