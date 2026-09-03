#!/usr/bin/env python3
"""Test the deterministic line-contract rules without invoking Typst."""

from __future__ import annotations

import sys
import unittest
from itertools import product
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import line_metrics  # noqa: E402
from ccvl_validation import ValidationError  # noqa: E402
from ccvl_validation.workspace import validate_line_contract, validate_line_contracts  # noqa: E402


def contract(text: str = "evidence", minimum: int = 75, target: int = 90, maximum: int = 100) -> dict[str, object]:
    return {"text": text, "min_fill": minimum, "target_fill": target, "max_fill": maximum}


def application(paragraph_lengths: tuple[int, ...] = (3, 6, 6, 5, 5, 3)) -> dict[str, object]:
    return {
        "tailored_cv": {"pages": 4, "summary": [contract() for _ in range(5)]},
        "tailored_cl": {
            "enabled": True,
            "paragraphs": [{"lines": [contract() for _ in range(length)]} for length in paragraph_lengths],
            "highlights": [contract(minimum=60, target=82) for _ in range(5)],
        },
    }


class LineContractTests(unittest.TestCase):
    def test_cv_only_opportunity_is_valid(self) -> None:
        draft = application()
        draft["tailored_cl"] = {"enabled": False}
        validate_line_contracts(draft, "fixture", require_text=True)

    def test_disabled_cover_letter_cannot_retain_hidden_content(self) -> None:
        draft = application()
        draft["tailored_cl"]["enabled"] = False
        with self.assertRaisesRegex(ValidationError, "disabled cover letter"):
            validate_line_contracts(draft, "fixture", require_text=True)

    def test_preferred_cover_letter_distribution_is_valid(self) -> None:
        validate_line_contracts(application((3, 6, 6, 5, 5, 3)), "fixture", require_text=True)

    def test_cover_letter_accepts_asymmetric_pairs_and_minimum(self) -> None:
        validate_line_contracts(application((3, 5, 7, 5, 5, 3)), "fixture", require_text=True)
        validate_line_contracts(application((3, 7, 5, 5, 5, 2)), "fixture", require_text=True)
        validate_line_contracts(application((3, 5, 5, 5, 5, 2)), "fixture", require_text=True)

    def test_eleven_line_pair_is_valid_but_dispreferred(self) -> None:
        validate_line_contracts(application((3, 5, 6, 5, 5, 3)), "fixture", require_text=True)

    def test_cover_letter_rejects_wrong_fixed_or_individual_budget(self) -> None:
        with self.assertRaisesRegex(ValidationError, r"paragraphs\[1\].*expected 3–3 lines"):
            validate_line_contracts(application((2, 6, 6, 5, 5, 3)), "fixture", require_text=True)
        with self.assertRaisesRegex(ValidationError, r"paragraphs\[2\].*expected 5–7 lines"):
            validate_line_contracts(application((3, 4, 6, 5, 5, 3)), "fixture", require_text=True)
        with self.assertRaisesRegex(ValidationError, r"paragraphs\[6\].*expected 2–3 lines"):
            validate_line_contracts(application((3, 6, 6, 5, 5, 4)), "fixture", require_text=True)

    def test_cover_letter_rejects_region_outside_tolerance(self) -> None:
        with self.assertRaisesRegex(ValidationError, r"paragraphs\[4:5\].*expected 10–12 shared lines"):
            validate_line_contracts(application((3, 5, 5, 6, 7, 2)), "fixture", require_text=True)

    def test_cover_letter_rejects_weakened_fill_floor(self) -> None:
        draft = application()
        draft["tailored_cl"]["paragraphs"][0]["lines"][0]["min_fill"] = 74
        with self.assertRaisesRegex(ValidationError, "weakens the required fill floor"):
            validate_line_contracts(draft, "fixture", require_text=True)

    def test_every_middle_paragraph_distribution_matches_the_declared_regions(self) -> None:
        for middle in product(range(4, 9), repeat=4):
            pair_one = middle[0] + middle[1]
            pair_two = middle[2] + middle[3]
            valid = (
                all(5 <= count <= 7 for count in middle)
                and 10 <= pair_one <= 12
                and 10 <= pair_two <= 12
                and 20 <= sum(middle) <= 22
            )
            draft = application((3, *middle, 3))
            with self.subTest(middle=middle):
                if valid:
                    validate_line_contracts(draft, "fixture", require_text=True)
                else:
                    with self.assertRaises(ValidationError):
                        validate_line_contracts(draft, "fixture", require_text=True)

    def test_fill_bounds_must_be_ordered(self) -> None:
        with self.assertRaisesRegex(ValidationError, "min_fill <= target_fill <= max_fill"):
            validate_line_contract(contract(minimum=90, target=80), "fixture", require_text=True)

    def test_empty_rendered_line_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValidationError, "cannot be empty"):
            validate_line_contract(contract(text="  "), "fixture", require_text=True)

    def test_underfill_and_overflow_are_both_failures(self) -> None:
        base = {"min_fill": 60, "target_fill": 80, "max_fill": 95}
        self.assertEqual(line_metrics.violation({**base, "actual_fill": 59.9}), "too short")
        self.assertIsNone(line_metrics.violation({**base, "actual_fill": 80.0}))
        self.assertEqual(line_metrics.violation({**base, "actual_fill": 95.1}), "too long")

    def test_vertical_layout_metrics_use_the_same_bounds(self) -> None:
        gap = {"min_fill": 12, "target_fill": 20, "max_fill": 30, "unit": "pt"}
        self.assertEqual(line_metrics.violation({**gap, "actual_fill": 11.9}), "too short")
        self.assertIsNone(line_metrics.violation({**gap, "actual_fill": 24.1}))
        self.assertEqual(line_metrics.violation({**gap, "actual_fill": 30.1}), "too long")

    def test_cover_letter_metric_set_requires_structure_and_layout_metrics(self) -> None:
        spec = line_metrics.DocumentSpec("fixture", "cl", Path("fixture.typ"), {})

        def metric(kind: str, identifier: str) -> dict[str, object]:
            return {"kind": kind, "id": identifier}

        def metric_set(paragraph_lengths: tuple[int, ...]) -> list[dict[str, object]]:
            body = [
                metric("cl-body", f"cl.paragraph.{paragraph}.{line}")
                for paragraph, length in enumerate(paragraph_lengths, start=1)
                for line in range(1, length + 1)
            ]
            return (
                body
                + [metric("cl-highlight", f"cl.highlight.{index}") for index in range(1, 6)]
                + [
                    metric("cl-vertical-gap", "cl.vertical-gap"),
                    metric("cl-highlight-center", "cl.highlight-center"),
                ]
            )

        complete = metric_set((3, 6, 6, 5, 5, 3))
        line_metrics.validate_metric_set(spec, complete)
        self.assertEqual(line_metrics.preference_warnings(spec, complete), [])

        dispreferred = metric_set((3, 5, 6, 5, 5, 3))
        line_metrics.validate_metric_set(spec, dispreferred)
        warnings = line_metrics.preference_warnings(spec, dispreferred)
        self.assertEqual(len(warnings), 1)
        self.assertTrue(any("paragraphs 2–3 use 11 lines" in warning for warning in warnings))

        shorter_close = metric_set((3, 5, 5, 5, 5, 2))
        line_metrics.validate_metric_set(spec, shorter_close)
        self.assertEqual(
            line_metrics.preference_warnings(spec, shorter_close),
            ["fixture: paragraph 6 uses 2 lines; accepted, but 3 is preferred to mirror paragraph 1"],
        )

        for missing_kind in ("cl-vertical-gap", "cl-highlight-center"):
            with self.subTest(missing_kind=missing_kind):
                incomplete = [item for item in complete if item["kind"] != missing_kind]
                with self.assertRaisesRegex(line_metrics.MeasurementError, "vertical-gap and one highlight-position"):
                    line_metrics.validate_metric_set(spec, incomplete)


if __name__ == "__main__":
    unittest.main()
