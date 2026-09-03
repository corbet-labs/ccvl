"""Validate the pinned cross-platform runtime and supply-chain contract."""

from __future__ import annotations

import csv
import re
import tomllib

from . import ROOT, ValidationError


TOOLS = {"typst", "typstyle", "uv"}
PLATFORMS = {
    "Linux-x86_64",
    "Linux-aarch64",
    "Darwin-x86_64",
    "Darwin-aarch64",
    "Windows-x86_64",
    "Windows-aarch64",
}


def validate_runtime_contract() -> None:
    with (ROOT / "scripts" / "tool-assets.csv").open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = set(reader.fieldnames or [])
    expected_fields = {"tool", "version", "platform", "asset", "sha256", "kind", "url"}
    if fields != expected_fields or not rows:
        raise ValidationError("scripts/tool-assets.csv: invalid or empty header")

    seen: set[tuple[str, str]] = set()
    versions: dict[str, set[str]] = {tool: set() for tool in TOOLS}
    for row in rows:
        key = (row["tool"], row["platform"])
        if key in seen:
            raise ValidationError(f"scripts/tool-assets.csv: duplicate asset {key}")
        seen.add(key)
        if row["tool"] not in TOOLS or row["platform"] not in PLATFORMS:
            raise ValidationError(f"scripts/tool-assets.csv: unknown tool or platform {key}")
        versions[row["tool"]].add(row["version"])
        if row["kind"] not in {"archive", "file"}:
            raise ValidationError(f"scripts/tool-assets.csv: invalid asset kind for {key}")
        if re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is None:
            raise ValidationError(f"scripts/tool-assets.csv: invalid SHA-256 for {key}")
        if not row["url"].startswith("https://github.com/") or not row["url"].endswith(row["asset"]):
            raise ValidationError(f"scripts/tool-assets.csv: invalid release URL for {key}")
    expected = {(tool, platform) for tool in TOOLS for platform in PLATFORMS}
    if seen != expected:
        raise ValidationError(f"scripts/tool-assets.csv: incomplete matrix {sorted(expected - seen)}")
    inconsistent = sorted(tool for tool, values in versions.items() if len(values) != 1)
    if inconsistent:
        raise ValidationError(f"scripts/tool-assets.csv: inconsistent versions for {', '.join(inconsistent)}")

    python_version = (ROOT / ".python-version").read_text(encoding="utf-8").strip()
    if re.fullmatch(r"3\.13\.\d+", python_version) is None:
        raise ValidationError(".python-version: expected an exact Python 3.13 patch release")
    project = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
    if project["project"].get("requires-python") != "==3.13.*":
        raise ValidationError("pyproject.toml: Python range must match the managed runtime")
    pypdf_dependencies = [
        item.removeprefix("pypdf==")
        for item in project["project"].get("dependencies", [])
        if item.startswith("pypdf==")
    ]
    if len(pypdf_dependencies) != 1 or re.fullmatch(r"\d+\.\d+\.\d+", pypdf_dependencies[0]) is None:
        raise ValidationError("pyproject.toml: pypdf must have one exact version pin")

    lock = tomllib.loads((ROOT / "uv.lock").read_text(encoding="utf-8"))
    if lock.get("requires-python") != "==3.13.*":
        raise ValidationError("uv.lock: Python range differs from pyproject.toml")
    locked_pypdf = [package for package in lock.get("package", []) if package.get("name") == "pypdf"]
    if len(locked_pypdf) != 1 or locked_pypdf[0].get("version") != pypdf_dependencies[0]:
        raise ValidationError("uv.lock: pypdf version differs from pyproject.toml")
    artifacts = [locked_pypdf[0].get("sdist", {}), *locked_pypdf[0].get("wheels", [])]
    if not artifacts or any(re.fullmatch(r"sha256:[0-9a-f]{64}", item.get("hash", "")) is None for item in artifacts):
        raise ValidationError("uv.lock: pypdf artifacts need SHA-256 hashes")
