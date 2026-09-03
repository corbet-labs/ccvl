#!/usr/bin/env python3
"""Cross-platform, reproducible Typst rendering for ccvl."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FONT_ROOT = ROOT / "cvl" / "shared" / "fonts"
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


def default_application(locale: str) -> Path:
    return ROOT / "showcase" / locale / "application.json"


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
    locale = normalize_locale(locale_value)
    if pages not in {2, 3, 4}:
        raise RenderError(f"CV pages must be 2, 3, or 4: {pages}")
    application_path = workspace_path(application or default_application(locale))
    profile_path = workspace_path(profile or ROOT / "showcase" / "profile.json")
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
    application_path = workspace_path(application or default_application(locale))
    profile_path = workspace_path(profile or ROOT / "showcase" / "profile.json")
    output_path = Path(output).resolve() if output else ROOT / "cvl" / "cl" / "output" / locale / "cl.pdf"
    return compile_pdf(
        ROOT / "cvl" / "cl" / locale / "main.typ",
        output_path,
        {"application": typst_path(application_path), "profile": typst_path(profile_path)},
    )


def render_all() -> list[Path]:
    outputs: list[Path] = []
    for locale in ("de-ch", "en-ch"):
        for pages in (2, 3, 4):
            outputs.append(render_cv(locale, pages))
        outputs.append(render_cl(locale))
    return outputs


def render_application(application: str | Path, locale: str, pages: int, profile: str | Path | None = None) -> list[Path]:
    application_path = workspace_path(application)
    document = json.loads(application_path.read_text(encoding="utf-8"))
    job_id = document["job"]["id"]
    if not isinstance(job_id, str) or re.fullmatch(r"[A-Za-z0-9_-]+", job_id) is None:
        raise RenderError("application job.id must contain only ASCII letters, numbers, hyphens, or underscores")
    destination = ROOT / "out" / job_id
    return [
        render_cv(locale, pages, application_path, profile, destination / "cv.pdf"),
        render_cl(locale, application_path, profile, destination / "cl.pdf"),
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("all")

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

    application = subparsers.add_parser("application")
    application.add_argument("application")
    application.add_argument("locale")
    application.add_argument("pages", type=int)
    application.add_argument("profile", nargs="?")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "all":
            outputs = render_all()
        elif args.command == "cv":
            outputs = [render_cv(args.locale, args.pages, args.application, args.profile, args.output)]
        elif args.command == "cl":
            outputs = [render_cl(args.locale, args.application, args.profile, args.output)]
        else:
            outputs = render_application(args.application, args.locale, args.pages, args.profile)
    except (KeyError, OSError, json.JSONDecodeError, RenderError) as exc:
        print(f"render failed: {exc}", file=sys.stderr)
        return 1
    for output in outputs:
        print(f"Rendered {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
