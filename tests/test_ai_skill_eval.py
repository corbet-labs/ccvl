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
        response["decisions"][0]["reason"] = "word " * 13
        response["decisions"].append(dict(response["decisions"][1]))
        result = ai_skill_eval.evaluate_response(self.cases, response)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("more than once" in error for error in result["errors"]))
        self.assertTrue(any("exceeds 12 words" in error for error in result["results"][0]["errors"]))

    def test_model_prompt_does_not_expose_answer_key(self) -> None:
        skills = {case["skill"]: "example skill" for case in self.cases}
        focus_skill = self.cases[0]["skill"]
        skills[focus_skill] = "---\ndescription: example skill\n---\n\n# Instructions\n"
        for name in skills:
            skills[name] = "---\ndescription: example skill\n---\n\n# Instructions\n"
        messages = ai_skill_eval.build_messages(self.document, skills, focus_skill)
        payload = json.loads(messages[1]["content"])
        for case in payload["cases"]:
            self.assertNotIn("skill", case)
            self.assertNotIn("required", case)
            self.assertNotIn("forbidden", case)

    def test_hosted_cases_are_batched_by_skill(self) -> None:
        batches = ai_skill_eval.group_cases_by_skill(self.cases)
        self.assertEqual([name for name, _ in batches], list(dict.fromkeys(case["skill"] for case in self.cases)))
        self.assertEqual(sum(len(cases) for _, cases in batches), len(self.cases))
        self.assertTrue(all({case["skill"] for case in cases} == {name} for name, cases in batches))

    def test_report_and_summary_are_written(self) -> None:
        evaluation = ai_skill_eval.evaluate_response(self.cases, self.passing_response())
        with tempfile.TemporaryDirectory(prefix="ccvl-eval-test-") as directory:
            report = Path(directory) / "report.json"
            summary = Path(directory) / "summary.md"
            ai_skill_eval.write_report(
                report,
                ai_skill_eval.DEFAULT_MODEL,
                evaluation,
                provider_details={"finish_reason": "stop", "usage": {"total_tokens": 42}},
            )
            ai_skill_eval.append_markdown_summary(summary, report)
            saved_report = ai_skill_eval.read_json(report)
            self.assertEqual(saved_report["status"], "passed")
            self.assertEqual(saved_report["provider_details"]["finish_reason"], "stop")
            self.assertIn("ccvl skill evaluation", summary.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
