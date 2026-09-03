#!/usr/bin/env python3
"""Enforce the public ccvl trust boundary on every supported platform."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import check  # noqa: E402
from ccvl_validation.repository import public_files  # noqa: E402


DEPRECATED_OR_PRIVATE_ROOTS = {"applications", "evidence", "out", "outcomes", "private", "sources", "submissions"}
PUBLIC_WORKSPACE_SCAFFOLDS = {
    Path("cvl/evidence/README.md"),
    Path("cvl/imports/README.md"),
    Path("opportunities/README.md"),
    Path("targets/README.md"),
}
SECRET_PATTERN = re.compile(
    rb"-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|"
    rb"github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|"
    rb"xox[baprs]-[A-Za-z0-9-]{10,}"
)


class PublicCheckError(Exception):
    pass


def relative_public_paths() -> list[Path]:
    return [path.relative_to(ROOT) for path in public_files()]


def check_public_boundary() -> None:
    present_private = sorted(name for name in DEPRECATED_OR_PRIVATE_ROOTS if (ROOT / name).exists())
    if present_private:
        raise PublicCheckError(f"private downstream paths exist: {', '.join(present_private)}")

    workspace_files = set()
    for relative in relative_public_paths():
        if relative.parts and relative.parts[0] in {"opportunities", "targets"}:
            workspace_files.add(relative)
        if relative.parts[:2] in {("cvl", "evidence"), ("cvl", "imports")}:
            workspace_files.add(relative)
    unexpected_workspace_files = sorted(workspace_files - PUBLIC_WORKSPACE_SCAFFOLDS)
    if unexpected_workspace_files:
        rendered = ", ".join(str(path) for path in unexpected_workspace_files)
        raise PublicCheckError(
            f"public workspace contains private evidence, import, target, or opportunity data: {rendered}"
        )

    for directory, names, files in os.walk(ROOT, followlinks=False):
        directory_path = Path(directory)
        relative_directory = directory_path.relative_to(ROOT)
        names[:] = [name for name in names if name not in {".git", ".cache"}]
        for name in [*names, *files]:
            path = directory_path / name
            if path.is_symlink():
                raise PublicCheckError(f"symlink requires manual publication review: {path.relative_to(ROOT)}")

    for path in (ROOT / "cvl").rglob("*"):
        is_lfs_pointer = path.is_file() and path.read_bytes().startswith(b"version https://git-lfs.github.com/spec/v1")
        if is_lfs_pointer:
            raise PublicCheckError(f"unresolved Git LFS pointer: {path.relative_to(ROOT)}")

    excluded_secret_prefixes = {
        Path("cvl/cl/assets/signature.png"),
    }
    for relative in relative_public_paths():
        is_bundled_font = relative.parts[:2] == ("cvl", "shared") and "fonts" in relative.parts
        if relative in excluded_secret_prefixes or is_bundled_font:
            continue
        if relative.suffix == ".pdf" and "output" in relative.parts:
            continue
        if SECRET_PATTERN.search((ROOT / relative).read_bytes()):
            raise PublicCheckError(f"potential secret found: {relative}")

    private_identifier = re.compile(rb"/home/richc|julian-corbet/applications|BEGIN OPENSSH PRIVATE KEY")
    allowed_identifier_files = {
        Path("PUBLIC_IDENTIFIERS.md"),
        Path("scripts/public-check.sh"),
        Path("scripts/public_check.py"),
    }
    for relative in relative_public_paths():
        if relative in allowed_identifier_files:
            continue
        if private_identifier.search((ROOT / relative).read_bytes()):
            raise PublicCheckError(f"private workspace identifier found: {relative}")


def main() -> int:
    try:
        check.run_checks()
        check_public_boundary()
    except (check.CheckError, check.ValidationError, OSError, PublicCheckError, RuntimeError, ValueError) as exc:
        print(f"public check failed: {exc}", file=sys.stderr)
        return 1
    print("Public-boundary checks passed. Review PUBLIC_IDENTIFIERS.md before publishing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
