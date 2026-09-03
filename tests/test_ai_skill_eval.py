#!/usr/bin/env python3
"""Mechanical tests for the semantic skill evaluator."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import ai_skill_eval  # noqa: E402


class SkillEvaluationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.document = ai_skill_eval.read_json(ROOT / "tests/skill-cases.json")
        cls.cases = cls.document["cases"]

    def passing_response(self) -> dict[str, object]:
        return {
            "decisions": [
                {
                    "case_id": case["id"],
                    "skill": case["skill"],
                    "selected": list(case["required"]),
                    "reason": "The selected actions follow the stated skill boundary.",
                }
                for case in self.cases
            ]
        }

    def test_required_only_response_passes(self) -> None:
        result = ai_skill_eval.evaluate_response(self.cases, self.passing_response())
        self.assertEqual(result["status"], "passed")
        self.assertTrue(all(item["passed"] for item in result["results"]))

    def test_forbidden_selection_fails_its_case(self) -> None:
        response = self.passing_response()
        response["decisions"][0]["selected"].append(self.cases[0]["forbidden"][0])
        result = ai_skill_eval.evaluate_response(self.cases, response)
        self.assertEqual(result["status"], "failed")
        self.assertIn("selected forbidden options", result["results"][0]["errors"][0])

    def test_missing_case_fails(self) -> None:
        response = self.passing_response()
        response["decisions"].pop()
        result = ai_skill_eval.evaluate_response(self.cases, response)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["results"][-1]["errors"], ["missing decision"])

    def test_unknown_option_fails(self) -> None:
        response = self.passing_response()
        response["decisions"][0]["selected"].append("not-a-real-option")
        result = ai_skill_eval.evaluate_response(self.cases, response)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("unknown options" in error for error in result["results"][0]["errors"]))

    def test_wrong_skill_routing_fails(self) -> None:
        response = self.passing_response()
        response["decisions"][0]["skill"] = "ccvl-cv"
        result = ai_skill_eval.evaluate_response(self.cases, response)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("routed to" in error for error in result["results"][0]["errors"]))

    def test_malformed_response_fails_cleanly(self) -> None:
        result = ai_skill_eval.evaluate_response(self.cases, {"answer": []})
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["results"], [])

    def test_duplicate_case_and_long_reason_fail(self) -> None:
        response = self.passing_response()
        response["decisions"][0]["reason"] = "word " * 26
        response["decisions"].append(dict(response["decisions"][1]))
        result = ai_skill_eval.evaluate_response(self.cases, response)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("more than once" in error for error in result["errors"]))
        self.assertTrue(any("exceeds 25 words" in error for error in result["results"][0]["errors"]))

    def test_model_prompt_does_not_expose_answer_key(self) -> None:
        skills = {case["skill"]: "example skill" for case in self.cases}
        messages = ai_skill_eval.build_messages(self.document, skills)
        payload = json.loads(messages[1]["content"])
        for case in payload["cases"]:
            self.assertNotIn("skill", case)
            self.assertNotIn("required", case)
            self.assertNotIn("forbidden", case)

    def test_report_and_summary_are_written(self) -> None:
        evaluation = ai_skill_eval.evaluate_response(self.cases, self.passing_response())
        with tempfile.TemporaryDirectory(prefix="ccvl-eval-test-") as directory:
            report = Path(directory) / "report.json"
            summary = Path(directory) / "summary.md"
            ai_skill_eval.write_report(report, ai_skill_eval.DEFAULT_MODEL, evaluation)
            ai_skill_eval.append_markdown_summary(summary, report)
            self.assertEqual(ai_skill_eval.read_json(report)["status"], "passed")
            self.assertIn("ccvl skill evaluation", summary.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
