#!/usr/bin/env python3
"""Create and resolve keyed ccvl opportunity records."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
OPPORTUNITIES_ROOT = ROOT / "opportunities"
TEMPLATE = ROOT / "templates" / "application.json"
KEY_PATTERN = re.compile(r"[a-z0-9]+(?:[-_][a-z0-9]+)*")


class OpportunityError(Exception):
    pass


def record_path(organisation_key: str, position_key: str, *, require_exists: bool = True) -> Path:
    for label, value in (("organisation", organisation_key), ("position", position_key)):
        if KEY_PATTERN.fullmatch(value) is None:
            raise OpportunityError(f"invalid {label} key: {value!r}")
    record = OPPORTUNITIES_ROOT / organisation_key / position_key / "application.json"
    if require_exists and not record.is_file():
        raise OpportunityError(f"opportunity record does not exist: {record.relative_to(ROOT)}")
    return record


def load_record(path: Path) -> dict[str, Any]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise OpportunityError(f"cannot read {path.relative_to(ROOT)}: {exc}") from exc
    if not isinstance(document, dict):
        raise OpportunityError(f"opportunity record must be a JSON object: {path.relative_to(ROOT)}")
    return document


def create_record(organisation_key: str, position_key: str) -> Path:
    destination = record_path(organisation_key, position_key, require_exists=False)
    if destination.exists():
        raise OpportunityError(f"refusing to overwrite existing opportunity: {destination.relative_to(ROOT)}")
    document = load_record(TEMPLATE)
    document["job"]["id"] = f"{organisation_key}--{position_key}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return destination


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("organisation_key")
    parser.add_argument("position_key")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        destination = create_record(args.organisation_key, args.position_key)
    except OpportunityError as exc:
        print(f"new opportunity failed: {exc}", file=sys.stderr)
        return 1
    print(f"Created {destination.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
