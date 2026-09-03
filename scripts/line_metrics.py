#!/usr/bin/env python3
"""Measure Typst line contracts and fail on underfill or overflow."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
FONT_ROOT = ROOT / "cvl" / "shared" / "fonts"
sys.path.insert(0, str(ROOT / "scripts"))

import render  # noqa: E402
import opportunity  # noqa: E402
import station_plan  # noqa: E402
from ccvl_validation import ValidationError  # noqa: E402
from ccvl_validation.schema import validate_json_file  # noqa: E402
from ccvl_validation.workspace import validate_line_contracts  # noqa: E402


class MeasurementError(Exception):
    pass


@dataclass(frozen=True)
class DocumentSpec:
    name: str
    kind: str
    source: Path
    inputs: dict[str, str]


def cover_letter_contract() -> dict[str, Any]:
    return json.loads((ROOT / "ccvl.json").read_text(encoding="utf-8"))["documents"]["cover_letter"]


def paragraph_line_counts(spec: DocumentSpec, metrics: list[dict[str, Any]]) -> list[int]:
    contract = cover_letter_contract()
    counts = [0 for _ in contract["paragraphs"]]
    pattern = re.compile(r"^cl\.paragraph\.(\d+)\.(\d+)$")
    for metric in metrics:
        if metric.get("kind") != "cl-body":
            continue
        match = pattern.fullmatch(str(metric.get("id", "")))
        if match is None:
            raise MeasurementError(f"{spec.name}: malformed cover-letter body metric id")
        paragraph_number = int(match.group(1))
        if not 1 <= paragraph_number <= len(counts):
            raise MeasurementError(f"{spec.name}: cover-letter body metric references an unknown paragraph")
        counts[paragraph_number - 1] += 1
    return counts


def preference_warnings(spec: DocumentSpec, metrics: list[dict[str, Any]]) -> list[str]:
    if spec.kind != "cl":
        return []
    contract = cover_letter_contract()
    paragraph_counts = paragraph_line_counts(spec, metrics)
    warnings: list[str] = []
    for region in contract["paragraph_regions"]:
        total = sum(paragraph_counts[number - 1] for number in region["paragraphs"])
        preferred = region["preferred_totals"]
        if total not in preferred:
            label = "–".join(str(number) for number in (region["paragraphs"][0], region["paragraphs"][-1]))
            warnings.append(
                f"{spec.name}: paragraphs {label} use {total} lines; accepted, but "
                f"{' or '.join(str(value) for value in preferred)} is preferred"
            )
    opening_number, closing_number = contract["mirror_paragraphs"]
    closing_contract = contract["paragraphs"][closing_number - 1]["lines"]
    closing_lines = paragraph_counts[closing_number - 1]
    if closing_lines != closing_contract["target"]:
        warnings.append(
            f"{spec.name}: paragraph {closing_number} uses {closing_lines} lines; accepted, but "
            f"{closing_contract['target']} is preferred to mirror paragraph {opening_number}"
        )
    return warnings


def general_specs() -> list[DocumentSpec]:
    try:
        station_plan.validate_general(require_ready=True)
    except ValidationError as exc:
        raise MeasurementError(f"CV station layout is not ready: {exc}") from exc
    specs: list[DocumentSpec] = []
    profile = render.typst_path(render.general_profile())
    for locale in ("de-ch", "en-ch"):
        application = render.typst_path(render.general_application(locale))
        common = {"application": application, "profile": profile, "line-contracts": "report"}
        specs.append(
            DocumentSpec(
                f"CV {locale}",
                "cv",
                ROOT / "cvl" / "cv" / locale / "main.typ",
                {**common, "cv-pages": "4"},
            )
        )
        specs.append(
            DocumentSpec(
                f"cover letter {locale}",
                "cl",
                ROOT / "cvl" / "cl" / locale / "main.typ",
                common,
            )
        )
    return specs


def opportunity_specs(organisation_key: str, position_key: str) -> list[DocumentSpec]:
    try:
        station_plan.validate_general(require_ready=True)
    except ValidationError as exc:
        raise MeasurementError(f"CV station layout is not ready: {exc}") from exc
    try:
        application_path = opportunity.record_path(organisation_key, position_key)
        document = validate_json_file(application_path, ROOT / "schemas" / "application.schema.json")
        validate_line_contracts(document, str(application_path.relative_to(ROOT)), require_text=True)
    except opportunity.OpportunityError as exc:
        raise MeasurementError(str(exc)) from exc
    except ValidationError as exc:
        raise MeasurementError(str(exc)) from exc
    try:
        locale = render.normalize_locale(str(document["job"]["language"]))
        pages = int(document["tailored_cv"]["pages"])
        cover_letter_enabled = document["tailored_cl"]["enabled"]
    except (KeyError, TypeError, ValueError) as exc:
        raise MeasurementError(f"incomplete opportunity record: {application_path.relative_to(ROOT)}") from exc
    if pages not in {2, 3, 4}:
        raise MeasurementError("tailored_cv.pages must be 2, 3, or 4")
    if not isinstance(cover_letter_enabled, bool):
        raise MeasurementError("tailored_cl.enabled must be a boolean")

    profile_path = render.general_profile()
    common = {
        "application": render.typst_path(application_path),
        "profile": render.typst_path(profile_path),
        "line-contracts": "report",
    }
    specs = [
        DocumentSpec(
            f"CV {organisation_key}/{position_key}",
            "cv",
            ROOT / "cvl" / "cv" / locale / "main.typ",
            {**common, "cv-pages": str(pages)},
        ),
    ]
    if cover_letter_enabled:
        specs.append(
            DocumentSpec(
                f"cover letter {organisation_key}/{position_key}",
                "cl",
                ROOT / "cvl" / "cl" / locale / "main.typ",
                common,
            )
        )
    return specs


def evaluate(spec: DocumentSpec) -> list[dict[str, Any]]:
    command = [
        "typst",
        "eval",
        "query(<ccvl-line>).map(it => it.value) + query(<ccvl-layout>).map(it => it.value)",
        "--in",
        str(spec.source),
        "--root",
        str(ROOT),
        "--font-path",
        str(FONT_ROOT),
        "--ignore-system-fonts",
        "--format",
        "json",
    ]
    for key, value in spec.inputs.items():
        command.extend(["--input", f"{key}={value}"])
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise MeasurementError(f"Typst metric query failed for {spec.name}: {detail}")
    if result.stderr.strip():
        raise MeasurementError(f"Typst metric query emitted diagnostics for {spec.name}: {result.stderr.strip()}")
    try:
        metrics = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise MeasurementError(f"Typst returned invalid metric JSON for {spec.name}") from exc
    if not isinstance(metrics, list):
        raise MeasurementError(f"Typst returned a non-list metric result for {spec.name}")
    return metrics


def validate_metric_set(spec: DocumentSpec, metrics: list[dict[str, Any]]) -> None:
    counts: dict[str, int] = {}
    for metric in metrics:
        kind = metric.get("kind")
        counts[kind] = counts.get(kind, 0) + 1
    if spec.kind == "cv":
        if counts.get("cv-summary") != 5:
            raise MeasurementError(f"{spec.name}: expected exactly five measured Summary lines")
        for required in ("cv-heading", "cv-subheading", "cv-bullet"):
            if not counts.get(required):
                raise MeasurementError(f"{spec.name}: no measured {required} lines found")
    elif spec.kind == "cl":
        body_lines = counts.get("cl-body", 0)
        contract = cover_letter_contract()
        paragraph_counts = paragraph_line_counts(spec, metrics)
        for paragraph_contract, actual_lines in zip(contract["paragraphs"], paragraph_counts, strict=True):
            line_contract = paragraph_contract["lines"]
            if not line_contract["minimum"] <= actual_lines <= line_contract["maximum"]:
                raise MeasurementError(
                    f"{spec.name}: paragraph {paragraph_contract['number']} ({paragraph_contract['role']}) "
                    f"must use {line_contract['minimum']}–{line_contract['maximum']} lines, found {actual_lines}"
                )
        for region in contract["paragraph_regions"]:
            region_lines = sum(paragraph_counts[number - 1] for number in region["paragraphs"])
            if not region["minimum"] <= region_lines <= region["maximum"]:
                raise MeasurementError(
                    f"{spec.name}: paragraphs {region['paragraphs'][0]}–{region['paragraphs'][-1]} must use "
                    f"{region['minimum']}–{region['maximum']} lines, found {region_lines}"
                )
        body_contract = contract["body_lines"]
        if not body_contract["minimum"] <= body_lines <= body_contract["maximum"]:
            raise MeasurementError(
                f"{spec.name}: expected {body_contract['minimum']}–{body_contract['maximum']} "
                f"body lines, found {body_lines}"
            )
        highlight_count = contract["highlights"]["count"]
        if counts.get("cl-highlight") != highlight_count:
            raise MeasurementError(f"{spec.name}: expected {highlight_count} one-line highlights")
        if counts.get("cl-vertical-gap") != 1 or counts.get("cl-highlight-center") != 1:
            raise MeasurementError(f"{spec.name}: expected one vertical-gap and one highlight-position metric")
        if len(metrics) != body_lines + highlight_count + 2:
            raise MeasurementError(f"{spec.name}: unexpected cover-letter metric set")


def violation(metric: dict[str, Any]) -> str | None:
    actual = metric["actual_fill"]
    if actual < metric["min_fill"]:
        return "too short"
    if actual > metric["max_fill"]:
        return "too long"
    return None


def compact_text(value: object, limit: int = 120) -> str:
    text = " ".join(str(value).split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def measure(specs: list[DocumentSpec], *, show_all: bool = False, emit: bool = True) -> list[str]:
    failures: list[str] = []
    for spec in specs:
        metrics = evaluate(spec)
        validate_metric_set(spec, metrics)
        advisories = preference_warnings(spec, metrics)
        if emit:
            for advisory in advisories:
                print(f"WARN {advisory}")
        document_failures: list[str] = []
        for index, metric in enumerate(metrics, start=1):
            state = violation(metric)
            if show_all or state:
                status = "PASS" if state is None else "FAIL"
                unit = metric.get("unit", "%")
                line = (
                    f"{status} {spec.name} #{index} {metric['kind']} {metric['actual_fill']:.1f}{unit} "
                    f"(target {metric['target_fill']}{unit}, allowed "
                    f"{metric['min_fill']}–{metric['max_fill']}{unit}): {compact_text(metric['text'])}"
                )
                if emit:
                    print(line)
            if state:
                unit = metric.get("unit", "%")
                document_failures.append(
                    f"{spec.name} #{index} {state}: {metric['actual_fill']:.1f}{unit} outside "
                    f"{metric['min_fill']}–{metric['max_fill']}{unit} "
                    f"(target {metric['target_fill']}{unit})"
                )
        failures.extend(document_failures)
        if emit and not show_all:
            warning_suffix = f", {len(advisories)} preference warning(s)" if advisories else ""
            print(
                f"{'PASS' if not document_failures else 'FAIL'} {spec.name}: "
                f"{len(metrics)} measured lines{warning_suffix}"
            )
    if failures and emit:
        message = (
            "Line measurement failed. Rewrite with relevant, verified signal—not filler—"
            "then run `ccvl measure` again."
        )
        print(
            message,
            file=sys.stderr,
        )
    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--opportunity", nargs=2, metavar=("ORGANISATION_KEY", "POSITION_KEY"))
    parser.add_argument("--all", action="store_true", help="print every measured line, not only failures")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.opportunity:
            specs = opportunity_specs(*args.opportunity)
        else:
            specs = general_specs()
        failures = measure(specs, show_all=args.all)
    except (KeyError, OSError, render.RenderError, MeasurementError) as exc:
        print(f"measure failed: {exc}", file=sys.stderr)
        return 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
