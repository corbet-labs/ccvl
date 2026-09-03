#!/usr/bin/env python3
"""Cross-platform, reproducible Typst rendering for ccvl."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

import opportunity
import station_plan
from ccvl_validation import ValidationError
from ccvl_validation.schema import validate_json_file
from ccvl_validation.workspace import validate_line_contracts


ROOT = Path(__file__).resolve().parent.parent
FONT_ROOT = ROOT / "cvl" / "shared" / "fonts"
GENERAL_ROOT = ROOT / "cvl" / "general"
LOCALES = {"de": "de-ch", "de-ch": "de-ch", "en": "en-ch", "en-ch": "en-ch"}


class RenderError(Exception):
    pass


def normalize_locale(value: str) -> str:
    try:
        return LOCALES[value.lower()]
    except KeyError as exc:
        raise RenderError(f"unsupported locale: {value}") from exc


def workspace_path(value: str | Path) -> Path:
    path = Path(value)
    resolved = path.resolve(strict=True) if path.is_absolute() else (ROOT / path).resolve(strict=True)
    try:
        resolved.relative_to(ROOT)
    except ValueError as exc:
        raise RenderError(f"input must be inside the ccvl workspace: {value}") from exc
    return resolved


def typst_path(value: str | Path) -> str:
    return "/" + workspace_path(value).relative_to(ROOT).as_posix()


def general_application(locale: str) -> Path:
    return GENERAL_ROOT / locale / "application.json"


def general_profile() -> Path:
    return GENERAL_ROOT / "profile.json"


def compile_pdf(source: Path, output: Path, inputs: dict[str, str]) -> Path:
    creation_timestamp = os.environ.get("SOURCE_DATE_EPOCH", "0")
    if not creation_timestamp.isdigit():
        raise RenderError("SOURCE_DATE_EPOCH must be a non-negative integer")
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "typst",
        "compile",
        "--root",
        str(ROOT),
        "--font-path",
        str(FONT_ROOT),
        "--ignore-system-fonts",
        "--creation-timestamp",
        creation_timestamp,
    ]
    for key, value in inputs.items():
        command.extend(["--input", f"{key}={value}"])
    command.extend([str(source), str(output)])
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise RenderError(f"Typst failed for {source.relative_to(ROOT)}: {detail}")
    if result.stderr.strip():
        raise RenderError(f"Typst emitted diagnostics for {source.relative_to(ROOT)}: {result.stderr.strip()}")
    if not output.is_file() or output.stat().st_size < 5 or output.read_bytes()[:5] != b"%PDF-":
        raise RenderError(f"Typst did not create a PDF: {output}")
    return output


def render_cv(
    locale_value: str,
    pages: int,
    application: str | Path | None = None,
    profile: str | Path | None = None,
    output: str | Path | None = None,
) -> Path:
    try:
        station_plan.validate_general(require_ready=True)
    except ValidationError as exc:
        raise RenderError(f"CV station layout is not ready: {exc}") from exc
    locale = normalize_locale(locale_value)
    if pages not in {2, 3, 4}:
        raise RenderError(f"CV pages must be 2, 3, or 4: {pages}")
    application_path = workspace_path(application or general_application(locale))
    profile_path = workspace_path(profile or general_profile())
    output_path = (
        Path(output).resolve()
        if output
        else ROOT / "cvl" / "cv" / "output" / locale / f"{pages}pager" / "cv.pdf"
    )
    return compile_pdf(
        ROOT / "cvl" / "cv" / locale / "main.typ",
        output_path,
        {
            "cv-pages": str(pages),
            "application": typst_path(application_path),
            "profile": typst_path(profile_path),
        },
    )


def render_cl(
    locale_value: str,
    application: str | Path | None = None,
    profile: str | Path | None = None,
    output: str | Path | None = None,
) -> Path:
    locale = normalize_locale(locale_value)
    application_path = workspace_path(application or general_application(locale))
    profile_path = workspace_path(profile or general_profile())
    output_path = Path(output).resolve() if output else ROOT / "cvl" / "cl" / "output" / locale / "cl.pdf"
    return compile_pdf(
        ROOT / "cvl" / "cl" / locale / "main.typ",
        output_path,
        {"application": typst_path(application_path), "profile": typst_path(profile_path)},
    )


def render_general() -> list[Path]:
    outputs: list[Path] = []
    for locale in ("de-ch", "en-ch"):
        for pages in (2, 3, 4):
            outputs.append(render_cv(locale, pages))
        outputs.append(render_cl(locale))
    return outputs


def render_opportunity(organisation_key: str, position_key: str) -> list[Path]:
    try:
        application_path = opportunity.record_path(organisation_key, position_key)
        document = validate_json_file(application_path, ROOT / "schemas" / "application.schema.json")
        validate_line_contracts(document, str(application_path.relative_to(ROOT)), require_text=True)
    except opportunity.OpportunityError as exc:
        raise RenderError(str(exc)) from exc
    except ValidationError as exc:
        raise RenderError(str(exc)) from exc
    try:
        locale = normalize_locale(str(document["job"]["language"]))
        pages = int(document["tailored_cv"]["pages"])
        cover_letter_enabled = document["tailored_cl"]["enabled"]
    except (KeyError, TypeError, ValueError) as exc:
        raise RenderError(f"incomplete opportunity record: {application_path.relative_to(ROOT)}") from exc
    if pages not in {2, 3, 4}:
        raise RenderError("tailored_cv.pages must be 2, 3, or 4")
    if not isinstance(cover_letter_enabled, bool):
        raise RenderError("tailored_cl.enabled must be a boolean")

    destination = application_path.parent / "output"
    outputs = [render_cv(locale, pages, application_path, general_profile(), destination / "cv.pdf")]
    if cover_letter_enabled:
        outputs.append(render_cl(locale, application_path, general_profile(), destination / "cl.pdf"))
    else:
        stale_cover_letter = destination / "cl.pdf"
        if stale_cover_letter.is_file():
            stale_cover_letter.unlink()
    return outputs


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("general")

    cv = subparsers.add_parser("cv")
    cv.add_argument("locale")
    cv.add_argument("pages", type=int)
    cv.add_argument("application", nargs="?")
    cv.add_argument("profile", nargs="?")
    cv.add_argument("output", nargs="?")

    cl = subparsers.add_parser("cl")
    cl.add_argument("locale")
    cl.add_argument("application", nargs="?")
    cl.add_argument("profile", nargs="?")
    cl.add_argument("output", nargs="?")

    opportunity = subparsers.add_parser("opportunity")
    opportunity.add_argument("organisation_key")
    opportunity.add_argument("position_key")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "general":
            outputs = render_general()
        elif args.command == "cv":
            outputs = [render_cv(args.locale, args.pages, args.application, args.profile, args.output)]
        elif args.command == "cl":
            outputs = [render_cl(args.locale, args.application, args.profile, args.output)]
        else:
            outputs = render_opportunity(args.organisation_key, args.position_key)
    except (KeyError, OSError, RenderError) as exc:
        print(f"render failed: {exc}", file=sys.stderr)
        return 1
    for output in outputs:
        print(f"Rendered {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
