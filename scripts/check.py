#!/usr/bin/env python3
"""Run ccvl's deterministic checks on Linux, macOS, and Windows."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import doctor  # noqa: E402
import line_metrics  # noqa: E402
import render  # noqa: E402
import station_plan  # noqa: E402
from ccvl_validation import ValidationError  # noqa: E402
from ccvl_validation.repository import validate_markdown_links, validate_text_files  # noqa: E402
from ccvl_validation.runtime import validate_runtime_contract  # noqa: E402
from ccvl_validation.skills import validate_skill_cases, validate_skills  # noqa: E402
from ccvl_validation.workspace import (  # noqa: E402
    validate_applications,
    validate_manifest,
    validate_profiles,
    validate_station_files,
)


class CheckError(Exception):
    pass


def dereference(value: Any) -> Any:
    return value.get_object() if hasattr(value, "get_object") else value


def run(command: list[str], *, reject_stderr: bool = False) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise CheckError(f"command failed ({' '.join(command)}): {detail}")
    if reject_stderr and result.stderr.strip():
        raise CheckError(f"command emitted diagnostics ({' '.join(command)}): {result.stderr.strip()}")
    return result


def check_fonts() -> None:
    expected = {
        "Archivo-Bold.ttf",
        "Archivo-Italic.ttf",
        "Archivo-Medium.ttf",
        "Archivo-Regular.ttf",
    }
    listing = run(
        ["typst", "fonts", "--font-path", "cvl/shared/fonts", "--ignore-system-fonts", "--variants"],
        reject_stderr=True,
    ).stdout
    if "Archivo" not in listing:
        raise CheckError("Typst did not discover the bundled Archivo family")
    for filename in expected:
        path = ROOT / "cvl" / "shared" / "fonts" / filename
        signature = path.read_bytes()[:4]
        if signature not in {b"\x00\x01\x00\x00", b"OTTO", b"true", b"typ1"}:
            raise CheckError(f"bundled font is missing or invalid: {filename}")
        if filename not in listing:
            raise CheckError(f"Typst did not load bundled font variant: {filename}")
    discovered = set(re.findall(r"Archivo-[A-Za-z]+\.ttf", listing))
    if discovered != expected:
        raise CheckError(f"expected exactly four Archivo variants; found {sorted(discovered)}")


def font_descriptor(font: Any) -> Any:
    font = dereference(font)
    descendants = font.get("/DescendantFonts")
    if descendants:
        font = dereference(descendants[0])
    descriptor = font.get("/FontDescriptor")
    return dereference(descriptor) if descriptor else None


def resources_have_image(resources: Any, seen: set[int] | None = None) -> bool:
    resources = dereference(resources)
    seen = seen or set()
    xobjects = dereference(resources.get("/XObject", {}))
    for reference in xobjects.values():
        item = dereference(reference)
        marker = id(item)
        if marker in seen:
            continue
        seen.add(marker)
        if item.get("/Subtype") == "/Image":
            return True
        if item.get("/Subtype") == "/Form" and item.get("/Resources"):
            if resources_have_image(item["/Resources"], seen):
                return True
    return False


def page_content(page: Any) -> bytes:
    contents = page.get_contents()
    return contents.get_data() if contents else b""


def check_pdf(path: Path, expected_pages: int, contacts: list[str], require_image: bool = False) -> PdfReader:
    reader = PdfReader(path, strict=True)
    if reader.is_encrypted:
        raise CheckError(f"{path} is encrypted")
    if len(reader.pages) != expected_pages:
        raise CheckError(f"{path} rendered {len(reader.pages)} pages; expected {expected_pages}")
    root = dereference(reader.trailer["/Root"])
    if root.get("/AcroForm"):
        raise CheckError(f"{path} contains a form")
    if root.get("/OpenAction") or root.get("/AA"):
        raise CheckError(f"{path} contains an automatic action")
    names = dereference(root.get("/Names", {}))
    if names.get("/JavaScript") or names.get("/EmbeddedFiles") or reader.attachments:
        raise CheckError(f"{path} contains JavaScript or embedded files")

    text_parts: list[str] = []
    fonts_seen = 0
    has_image = False
    for page in reader.pages:
        if abs(float(page.mediabox.width) - 595.2756) > 0.1 or abs(float(page.mediabox.height) - 841.8898) > 0.1:
            raise CheckError(f"{path} is not A4")
        if page.get("/AA"):
            raise CheckError(f"{path} contains a page action")
        text_parts.append(page.extract_text() or "")
        resources = dereference(page.get("/Resources", {}))
        has_image = has_image or resources_have_image(resources)
        fonts = dereference(resources.get("/Font", {}))
        for font_reference in fonts.values():
            font = dereference(font_reference)
            fonts_seen += 1
            base_font = str(font.get("/BaseFont", ""))
            if re.fullmatch(r"/[A-Z]{6}\+Archivo-(Bold|Italic|Medium|Regular)", base_font) is None:
                raise CheckError(f"{path} contains a fallback or unsubsetted font: {base_font}")
            if "/ToUnicode" not in font:
                raise CheckError(f"{path} contains a font without a Unicode map: {base_font}")
            descriptor = font_descriptor(font)
            if not descriptor or not any(key in descriptor for key in ("/FontFile", "/FontFile2", "/FontFile3")):
                raise CheckError(f"{path} contains an unembedded font: {base_font}")
    if not fonts_seen:
        raise CheckError(f"{path} contains no fonts")
    if require_image and not has_image:
        raise CheckError(f"{path} is missing its rendered signature image")
    extracted_text = "\n".join(text_parts)
    if len(re.sub(r"\s", "", extracted_text)) < 100:
        raise CheckError(f"{path} has no usable text layer")
    for literal in contacts:
        if literal not in extracted_text:
            raise CheckError(f"{path} is missing machine-readable contact text: {literal}")
    return reader


def run_python_tests() -> None:
    suite = unittest.defaultTestLoader.discover(str(ROOT / "tests"), pattern="test_*.py")
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    if not result.wasSuccessful():
        raise CheckError("Python unit tests failed")


def render_suite(destination: Path) -> None:
    for locale in ("de-ch", "en-ch"):
        for pages in (2, 3, 4):
            render.render_cv(locale, pages, output=destination / f"cv-{locale}-{pages}.pdf")
        render.render_cl(locale, output=destination / f"cl-{locale}.pdf")


def run_checks() -> None:
    if doctor.main() != 0:
        raise CheckError("toolchain doctor failed")
    validate_runtime_contract()
    validate_manifest()
    validate_profiles()
    validate_station_files()
    validate_applications()
    validate_skills()
    validate_skill_cases()
    validate_markdown_links()
    validate_text_files()
    run_python_tests()
    if os.name != "nt":
        run(["bash", "tests/test_bootstrap.sh"])
    run(["typstyle", "--check", "--line-width", "120", "cvl"], reject_stderr=True)
    station_plan.validate_general(require_ready=True)
    check_fonts()
    line_failures = line_metrics.measure(line_metrics.general_specs(), emit=False)
    if line_failures:
        raise CheckError("line measurement failed: " + "; ".join(line_failures))

    profile = json.loads((ROOT / "cvl" / "general" / "profile.json").read_text(encoding="utf-8"))
    contacts = [profile["name"], profile["email"], profile["phone_label"]]
    with tempfile.TemporaryDirectory(prefix="ccvl-check-") as directory:
        temporary = Path(directory)
        first = temporary / "first"
        second = temporary / "second"
        render_suite(first)
        render_suite(second)
        for locale in ("de-ch", "en-ch"):
            readers: dict[int, PdfReader] = {}
            for pages in (2, 3, 4):
                generated = first / f"cv-{locale}-{pages}.pdf"
                readers[pages] = check_pdf(generated, pages, contacts)
                if generated.read_bytes() != (second / generated.name).read_bytes():
                    raise CheckError(f"CV build is not byte-reproducible: {locale} {pages} pages")
                tracked = ROOT / "cvl" / "cv" / "output" / locale / f"{pages}pager" / "cv.pdf"
                if generated.read_bytes() != tracked.read_bytes():
                    raise CheckError(f"tracked CV output is stale or platform-dependent: {locale} {pages} pages")
            for page_index in (0, 1):
                baseline = page_content(readers[2].pages[page_index])
                if any(page_content(readers[pages].pages[page_index]) != baseline for pages in (3, 4)):
                    raise CheckError(f"shared CV page changed across presets: {locale} page {page_index + 1}")

            generated_cl = first / f"cl-{locale}.pdf"
            check_pdf(generated_cl, 1, contacts, require_image=True)
            if generated_cl.read_bytes() != (second / generated_cl.name).read_bytes():
                raise CheckError(f"cover-letter build is not byte-reproducible: {locale}")
            tracked_cl = ROOT / "cvl" / "cl" / "output" / locale / "cl.pdf"
            if generated_cl.read_bytes() != tracked_cl.read_bytes():
                raise CheckError(f"tracked cover-letter output is stale or platform-dependent: {locale}")


def main() -> int:
    try:
        run_checks()
    except (CheckError, KeyError, OSError, RuntimeError, ValidationError, ValueError) as exc:
        print(f"check failed: {exc}", file=sys.stderr)
        return 1
    print(
        "All cross-platform data, station, source, skill, font, reproducibility, "
        "CV, and cover-letter checks passed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
