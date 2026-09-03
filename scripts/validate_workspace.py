#!/usr/bin/env python3
"""Run ccvl's dependency-free workspace validation suite."""

from __future__ import annotations

import sys

from ccvl_validation import ValidationError
from ccvl_validation.repository import validate_markdown_links, validate_text_files
from ccvl_validation.runtime import validate_runtime_contract
from ccvl_validation.skills import validate_skill_cases, validate_skills
from ccvl_validation.workspace import validate_applications, validate_manifest, validate_profiles


def main() -> int:
    try:
        validate_manifest()
        validate_profiles()
        validate_applications()
        validate_skills()
        validate_skill_cases()
        validate_runtime_contract()
        validate_markdown_links()
        validate_text_files()
    except (KeyError, OSError, ValidationError, ValueError) as exc:
        print(f"validation failed: {exc}", file=sys.stderr)
        return 1
    print("Workspace data, repository, and skill contracts are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
