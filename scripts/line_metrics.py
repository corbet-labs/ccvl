#!/usr/bin/env python3
"""Measure Typst line contracts and fail on underfill or overflow."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
FONT_ROOT = ROOT / "cvl" / "shared" / "fonts"
sys.path.insert(0, str(ROOT / "scripts"))

import render  # noqa: E402


class MeasurementError(Exception):
    pass


@dataclass(frozen=True)
class DocumentSpec:
    name: str
    kind: str
    source: Path
    inputs: dict[str, str]


def showcase_specs() -> list[DocumentSpec]:
    specs: list[DocumentSpec] = []
    profile = render.typst_path(ROOT / "showcase" / "profile.json")
    for locale in ("de-ch", "en-ch"):
        application = render.typst_path(render.default_application(locale))
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


def application_specs(application: str, locale_value: str, pages: int, profile: str | None) -> list[DocumentSpec]:
    locale = render.normalize_locale(locale_value)
    application_path = render.workspace_path(application)
    profile_path = render.workspace_path(profile or ROOT / "showcase" / "profile.json")
    common = {
        "application": render.typst_path(application_path),
        "profile": render.typst_path(profile_path),
        "line-contracts": "report",
    }
    return [
        DocumentSpec(
            f"CV {locale}",
            "cv",
            ROOT / "cvl" / "cv" / locale / "main.typ",
            {**common, "cv-pages": str(pages)},
        ),
        DocumentSpec(
            f"cover letter {locale}",
            "cl",
            ROOT / "cvl" / "cl" / locale / "main.typ",
            common,
        ),
    ]


def evaluate(spec: DocumentSpec) -> list[dict[str, Any]]:
    command = [
        "typst",
        "eval",
        "query(<ccvl-line>).map(it => it.value)",
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
    elif counts.get("cl-body") != 15 or counts.get("cl-highlight") != 5 or len(metrics) != 20:
        raise MeasurementError(f"{spec.name}: expected 15 body lines and five one-line highlights")


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
        document_failures: list[str] = []
        for index, metric in enumerate(metrics, start=1):
            state = violation(metric)
            if show_all or state:
                status = "PASS" if state is None else "FAIL"
                line = (
                    f"{status} {spec.name} #{index} {metric['kind']} {metric['actual_fill']:.1f}% "
                    f"(target {metric['target_fill']}%, allowed {metric['min_fill']}–{metric['max_fill']}%): "
                    f"{compact_text(metric['text'])}"
                )
                if emit:
                    print(line)
            if state:
                document_failures.append(
                    f"{spec.name} #{index} {state}: {metric['actual_fill']:.1f}% outside "
                    f"{metric['min_fill']}–{metric['max_fill']}% (target {metric['target_fill']}%)"
                )
        failures.extend(document_failures)
        if emit and not show_all:
            print(f"{'PASS' if not document_failures else 'FAIL'} {spec.name}: {len(metrics)} measured lines")
    if failures and emit:
        print(
            "Line measurement failed. Rewrite with relevant, verified signal—not filler—then run `ccvl measure` again.",
            file=sys.stderr,
        )
    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application")
    parser.add_argument("--locale")
    parser.add_argument("--pages", type=int, default=4)
    parser.add_argument("--profile")
    parser.add_argument("--all", action="store_true", help="print every measured line, not only failures")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.application:
            if not args.locale:
                raise MeasurementError("--locale is required with --application")
            specs = application_specs(args.application, args.locale, args.pages, args.profile)
        elif args.locale or args.profile:
            raise MeasurementError("--locale and --profile require --application")
        else:
            specs = showcase_specs()
        failures = measure(specs, show_all=args.all)
    except (KeyError, OSError, render.RenderError, MeasurementError) as exc:
        print(f"measure failed: {exc}", file=sys.stderr)
        return 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
