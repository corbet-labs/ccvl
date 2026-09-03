#!/usr/bin/env python3
"""Test the deterministic line-contract rules without invoking Typst."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import line_metrics  # noqa: E402
from ccvl_validation import ValidationError  # noqa: E402
from ccvl_validation.workspace import validate_line_contract, validate_line_contracts  # noqa: E402


def contract(text: str = "evidence", minimum: int = 60, target: int = 80, maximum: int = 100) -> dict[str, object]:
    return {"text": text, "min_fill": minimum, "target_fill": target, "max_fill": maximum}


def application(paragraph_lengths: tuple[int, ...] = (3, 3, 3, 3, 3)) -> dict[str, object]:
    return {
        "tailored_cv": {"summary": [contract() for _ in range(5)]},
        "tailored_cl": {
            "paragraphs": [{"lines": [contract() for _ in range(length)]} for length in paragraph_lengths],
            "highlights": [contract() for _ in range(5)],
        },
    }


class LineContractTests(unittest.TestCase):
    def test_shared_cover_letter_budgets_allow_redistribution(self) -> None:
        validate_line_contracts(application((2, 4, 3, 4, 2)), "fixture", require_text=True)

    def test_cover_letter_accepts_one_line_either_side_of_target(self) -> None:
        validate_line_contracts(application((2, 3, 3, 3, 3)), "fixture", require_text=True)
        validate_line_contracts(application((3, 3, 3, 3, 4)), "fixture", require_text=True)

    def test_cover_letter_rejects_body_outside_tolerance(self) -> None:
        with self.assertRaisesRegex(ValidationError, "expected 14–16 body lines"):
            validate_line_contracts(application((2, 2, 2, 3, 3)), "fixture", require_text=True)
        with self.assertRaisesRegex(ValidationError, "expected 14–16 body lines"):
            validate_line_contracts(application((3, 3, 4, 3, 4)), "fixture", require_text=True)

    def test_cover_letter_rejects_unbalanced_regions(self) -> None:
        with self.assertRaisesRegex(ValidationError, "expected 8–10 shared lines"):
            validate_line_contracts(application((2, 2, 3, 3, 4)), "fixture", require_text=True)
        with self.assertRaisesRegex(ValidationError, "expected 5–7 shared lines"):
            validate_line_contracts(application((3, 3, 4, 2, 2)), "fixture", require_text=True)

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
        gap = {"min_fill": 30, "target_fill": 45, "max_fill": 55, "unit": "pt"}
        self.assertEqual(line_metrics.violation({**gap, "actual_fill": 29.9}), "too short")
        self.assertIsNone(line_metrics.violation({**gap, "actual_fill": 47.2}))
        self.assertEqual(line_metrics.violation({**gap, "actual_fill": 55.1}), "too long")

    def test_cover_letter_metric_set_requires_structure_and_layout_metrics(self) -> None:
        spec = line_metrics.DocumentSpec("fixture", "cl", Path("fixture.typ"), {})

        def metric(kind: str) -> dict[str, object]:
            return {"kind": kind}

        for body_lines in (14, 15, 16):
            metrics = (
                [metric("cl-body") for _ in range(body_lines)]
                + [metric("cl-highlight") for _ in range(5)]
                + [metric("cl-vertical-gap"), metric("cl-highlight-center")]
            )
            line_metrics.validate_metric_set(spec, metrics)

        complete = (
            [metric("cl-body") for _ in range(15)]
            + [metric("cl-highlight") for _ in range(5)]
            + [metric("cl-vertical-gap"), metric("cl-highlight-center")]
        )
        for missing_kind in ("cl-vertical-gap", "cl-highlight-center"):
            with self.subTest(missing_kind=missing_kind):
                incomplete = [item for item in complete if item["kind"] != missing_kind]
                with self.assertRaisesRegex(line_metrics.MeasurementError, "vertical-gap and one highlight-position"):
                    line_metrics.validate_metric_set(spec, incomplete)


if __name__ == "__main__":
    unittest.main()
