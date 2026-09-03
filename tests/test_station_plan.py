#!/usr/bin/env python3
"""Test deterministic CV station coverage and MECE ownership."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import station_plan  # noqa: E402
import render  # noqa: E402
from ccvl_validation import ValidationError  # noqa: E402


def station(index: int, page: int | None, *, status: str = "verified", experience: bool = False) -> dict[str, object]:
    return {
        "id": f"station-{index}",
        "label": f"Station {index}",
        "anchor": "Example context | 2020–2021",
        "kind": "employment" if experience else "education",
        "status": status,
        "page": page,
        "section": "experience" if page == 1 else "education" if page == 2 else "",
        "experience_eligible": experience,
        "facts": [{"id": f"fact-{index}", "text": f"Fact {index}"}],
        "source_refs": ["user-confirmed:2026-09-03"],
    }


def plan(page_one: int, page_two: int) -> dict[str, object]:
    stations = [station(index, 1, experience=True) for index in range(1, page_one + 1)]
    stations.extend(station(100 + index, 2) for index in range(1, page_two + 1))
    return {"schema_version": 1, "updated": "2026-09-03", "stations": stations}


class StationPlanTests(unittest.TestCase):
    def test_six_to_eight_and_about_ten_are_ready(self) -> None:
        for page_one in (6, 7, 8):
            for page_two in (9, 10, 11):
                with self.subTest(page_one=page_one, page_two=page_two):
                    self.assertTrue(station_plan.assess(plan(page_one, page_two)).ready)

    def test_underfilled_or_overcrowded_pages_require_iteration(self) -> None:
        for page_one, page_two, phrase in (
            (5, 10, "page 1 is underfilled"),
            (9, 10, "page 1 is overcrowded"),
            (7, 8, "page 2 is underfilled"),
            (7, 12, "page 2 is overcrowded"),
        ):
            with self.subTest(page_one=page_one, page_two=page_two):
                result = station_plan.assess(plan(page_one, page_two))
                self.assertFalse(result.ready)
                self.assertTrue(any(phrase in problem for problem in result.problems))

    def test_only_verified_assigned_stations_count(self) -> None:
        document = plan(6, 9)
        document["stations"][0]["status"] = "unverified"
        result = station_plan.assess(document)
        self.assertEqual(result.page_counts[1], 5)
        self.assertIn("station-1", result.unresolved_assigned)
        self.assertFalse(result.ready)

    def test_unassigned_experience_candidates_are_reported(self) -> None:
        document = plan(5, 9)
        document["stations"].append(station(999, None, experience=True))
        result = station_plan.assess(document)
        self.assertEqual(result.experience_candidates, ("station-999",))
        self.assertIn("station-999", station_plan.format_report(result))

    def test_one_fact_cannot_appear_in_two_stations(self) -> None:
        document = plan(6, 9)
        document["stations"][1]["facts"][0]["id"] = "fact-1"
        with self.assertRaisesRegex(ValidationError, "MECE assignment requires one owner"):
            station_plan.assess(document)

    def test_page_and_section_are_assigned_together(self) -> None:
        document = plan(6, 9)
        document["stations"][0]["section"] = ""
        with self.assertRaisesRegex(ValidationError, "page and section must be assigned together"):
            station_plan.assess(document)

    def test_compact_lines_do_not_pad_station_counts(self) -> None:
        source = (
            "// ccvl-station: one\n#cv-h[One]\n#cv-hu[Compact]\n#cv-pagebreak()\n"
            "// ccvl-station: two\n#cv-h[Two]\n#cv-hu[Compact]\n"
        )
        with tempfile.TemporaryDirectory(dir=ROOT, prefix=".station-source-") as directory:
            path = Path(directory) / "cv.typ"
            path.write_text(source, encoding="utf-8")
            self.assertEqual(station_plan.count_typst_stations(path), {1: 1, 2: 1})

    def test_every_full_entry_requires_a_station_marker(self) -> None:
        source = "#cv-h[Unmarked]\n#cv-pagebreak()\n// ccvl-station: two\n#cv-h[Two]\n"
        with tempfile.TemporaryDirectory(dir=ROOT, prefix=".station-source-") as directory:
            path = Path(directory) / "cv.typ"
            path.write_text(source, encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "1 full entries but 0 ccvl-station markers"):
                station_plan.count_typst_stations(path)

    def test_checked_in_general_plan_matches_both_locales(self) -> None:
        result = station_plan.validate_general(require_ready=True)
        self.assertEqual(result.page_counts, {1: 8, 2: 10})

    def test_cv_render_stops_on_an_underfilled_plan(self) -> None:
        with patch.object(station_plan, "validate_general", side_effect=ValidationError("page 1 is underfilled")):
            with self.assertRaisesRegex(render.RenderError, "CV station layout is not ready"):
                render.render_cv("en-ch", 2)


if __name__ == "__main__":
    unittest.main()
