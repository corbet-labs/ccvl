"""Validate public text hygiene and relative documentation links without Git."""

from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import unquote

from . import ROOT, ValidationError


EXCLUDED_ROOTS = {
    ".cache",
    ".git",
    "applications",
    "evidence",
    "out",
    "outcomes",
    "private",
    "sources",
    "submissions",
    "targets",
}
TEXT_SUFFIXES = {".cmd", ".csv", ".json", ".lock", ".md", ".ps1", ".py", ".sh", ".toml", ".typ", ".yaml", ".yml"}
TEXT_NAMES = {".gitattributes", ".gitignore", ".python-version", "ccvl", "justfile"}


def public_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if relative.parts[0] in EXCLUDED_ROOTS or "__pycache__" in relative.parts:
            continue
        files.append(path)
    return sorted(files)


def validate_markdown_links() -> None:
    link_pattern = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")
    errors: list[str] = []
    for path in (candidate for candidate in public_files() if candidate.suffix == ".md"):
        for raw_destination in link_pattern.findall(path.read_text(encoding="utf-8")):
            destination = raw_destination.strip()
            if destination.startswith("<") and ">" in destination:
                destination = destination[1 : destination.index(">")]
            else:
                destination = destination.split(maxsplit=1)[0]
            if not destination or destination.startswith(("#", "http://", "https://", "mailto:")):
                continue
            relative = unquote(destination.split("#", 1)[0].split("?", 1)[0])
            candidate = ROOT / relative.lstrip("/") if relative.startswith("/") else path.parent / relative
            if not candidate.exists():
                errors.append(f"{path.relative_to(ROOT)} -> {destination}")
    if errors:
        raise ValidationError("broken local Markdown links: " + ", ".join(errors))


def validate_text_files() -> None:
    errors: list[str] = []
    for path in public_files():
        if path.suffix not in TEXT_SUFFIXES and path.name not in TEXT_NAMES:
            continue
        relative = path.relative_to(ROOT)
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            errors.append(f"{relative}: not valid UTF-8")
            continue
        if text and not text.endswith("\n"):
            errors.append(f"{relative}: missing final newline")
        if "\r" in text:
            errors.append(f"{relative}: contains CR line endings")
        if re.search(r"[ \t]+$", text, flags=re.MULTILINE):
            errors.append(f"{relative}: trailing whitespace")
        if re.search(r"^(<{7}|={7}|>{7})(?: |$)", text, flags=re.MULTILINE):
            errors.append(f"{relative}: unresolved merge marker")
    if errors:
        raise ValidationError("text hygiene failures: " + ", ".join(errors))
