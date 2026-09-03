#!/usr/bin/env python3
"""Verify ccvl's pinned cross-platform runtime."""

from __future__ import annotations

import csv
import platform
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

import pypdf


ROOT = Path(__file__).resolve().parent.parent
EXPECTED_PYTHON = (ROOT / ".python-version").read_text(encoding="utf-8").strip()


def expected_pypdf_version() -> str:
    project = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
    matches = [
        dependency.removeprefix("pypdf==")
        for dependency in project["project"]["dependencies"]
        if dependency.startswith("pypdf==")
    ]
    if len(matches) != 1:
        raise RuntimeError("pyproject.toml must pin exactly one pypdf version")
    return matches[0]


def platform_key() -> str:
    system = platform.system()
    machine = platform.machine().lower()
    architectures = {
        "amd64": "x86_64",
        "x86_64": "x86_64",
        "arm64": "aarch64",
        "aarch64": "aarch64",
    }
    if system not in {"Linux", "Darwin", "Windows"} or machine not in architectures:
        raise RuntimeError(f"unsupported platform: {system}-{machine}")
    return f"{system}-{architectures[machine]}"


def expected_versions() -> dict[str, str]:
    with (ROOT / "scripts" / "tool-assets.csv").open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    selected = {row["tool"]: row["version"] for row in rows if row["platform"] == platform_key()}
    if set(selected) != {"typst", "typstyle", "uv"}:
        raise RuntimeError(f"incomplete tool asset table for {platform_key()}")
    return selected


def command_version(command: str) -> tuple[Path, str]:
    resolved = shutil.which(command)
    if not resolved:
        raise RuntimeError(f"required command is missing: {command}")
    result = subprocess.run([resolved, "--version"], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"{command} --version failed")
    return Path(resolved), (result.stdout or result.stderr).strip()


def main() -> int:
    try:
        versions = expected_versions()
        expected_pypdf = expected_pypdf_version()
        patterns = {
            "typst": f"typst {versions['typst']}",
            "typstyle": versions["typstyle"],
            "uv": f"uv {versions['uv']}",
        }
        for command, expected in patterns.items():
            path, actual = command_version(command)
            if expected not in actual:
                raise RuntimeError(f"{command} {expected} is required; found: {actual}")
            summary = " | ".join(line.strip() for line in actual.splitlines() if line.strip())
            print(f"{command:<10} {path} ({summary})")
        actual_python = platform.python_version()
        if actual_python != EXPECTED_PYTHON:
            raise RuntimeError(f"Python {EXPECTED_PYTHON} is required; found: {actual_python}")
        if pypdf.__version__ != expected_pypdf:
            raise RuntimeError(f"pypdf {expected_pypdf} is required; found: {pypdf.__version__}")
        print(f"{'python':<10} {Path(sys.executable)} ({actual_python})")
        print(f"{'pypdf':<10} {pypdf.__version__}")
    except (KeyError, OSError, RuntimeError, ValueError) as exc:
        print(f"doctor failed: {exc}", file=sys.stderr)
        return 1
    print("ccvl cross-platform toolchain is ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
