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

    def test_shared_cover_letter_budget_rejects_wrong_total(self) -> None:
        with self.assertRaisesRegex(ValidationError, "shared budget of 9 lines"):
            validate_line_contracts(application((2, 3, 3, 3, 3)), "fixture", require_text=True)

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


if __name__ == "__main__":
    unittest.main()
