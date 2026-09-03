#!/usr/bin/env python3
"""Validate ccvl data and skill contracts without third-party Python packages."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent


class ValidationError(Exception):
    pass


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValidationError(f"{path.relative_to(ROOT)}: {exc}") from exc


def value_has_type(value: Any, expected: str) -> bool:
    checks = {
        "array": lambda item: isinstance(item, list),
        "integer": lambda item: isinstance(item, int) and not isinstance(item, bool),
        "null": lambda item: item is None,
        "object": lambda item: isinstance(item, dict),
        "string": lambda item: isinstance(item, str),
    }
    if expected not in checks:
        raise ValidationError(f"validator does not support JSON Schema type {expected!r}")
    return checks[expected](value)


def resolve_ref(schema_root: dict[str, Any], reference: str) -> dict[str, Any]:
    if not reference.startswith("#/"):
        raise ValidationError(f"validator only supports local schema references: {reference}")
    node: Any = schema_root
    for raw_part in reference[2:].split("/"):
        part = raw_part.replace("~1", "/").replace("~0", "~")
        node = node[part]
    return node


def validate_schema(
    value: Any,
    schema: dict[str, Any],
    schema_root: dict[str, Any],
    location: str,
) -> None:
    if "$ref" in schema:
        validate_schema(value, resolve_ref(schema_root, schema["$ref"]), schema_root, location)
        return

    if "const" in schema and value != schema["const"]:
        raise ValidationError(f"{location}: expected constant {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValidationError(f"{location}: {value!r} is not in {schema['enum']!r}")

    expected_types = schema.get("type")
    if expected_types is not None:
        if isinstance(expected_types, str):
            expected_types = [expected_types]
        if not any(value_has_type(value, expected) for expected in expected_types):
            raise ValidationError(f"{location}: expected type {' or '.join(expected_types)}")

    if isinstance(value, dict):
        required = schema.get("required", [])
        missing = [field for field in required if field not in value]
        if missing:
            raise ValidationError(f"{location}: missing required fields {', '.join(missing)}")
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            unknown = sorted(set(value) - set(properties))
            if unknown:
                raise ValidationError(f"{location}: unknown fields {', '.join(unknown)}")
        for key, child in value.items():
            if key in properties:
                validate_schema(child, properties[key], schema_root, f"{location}.{key}")

    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            raise ValidationError(f"{location}: too few items")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            raise ValidationError(f"{location}: too many items")
        if "items" in schema:
            for index, child in enumerate(value):
                validate_schema(child, schema["items"], schema_root, f"{location}[{index}]")

    if isinstance(value, int) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            raise ValidationError(f"{location}: value is below minimum {schema['minimum']}")

    if isinstance(value, str) and "pattern" in schema:
        if re.fullmatch(schema["pattern"], value) is None:
            raise ValidationError(f"{location}: value does not match {schema['pattern']!r}")


def validate_json_file(path: Path, schema_path: Path) -> dict[str, Any]:
    schema = load_json(schema_path)
    value = load_json(path)
    validate_schema(value, schema, schema, str(path.relative_to(ROOT)))
    return value


def validate_manifest() -> None:
    manifest = load_json(ROOT / "ccvl.json")
    if manifest.get("format") != "ccvl-workspace" or manifest.get("schema_version") != 1:
        raise ValidationError("ccvl.json: unsupported workspace format or schema version")

    path_fields = [
        manifest["application_schema"],
        manifest["profile_schema"],
        manifest["showcase"]["profile"],
        manifest["showcase"]["de-CH"],
        manifest["showcase"]["en-CH"],
        manifest["documents"]["cv"]["de-CH"],
        manifest["documents"]["cv"]["en-CH"],
        manifest["documents"]["cover_letter"]["de-CH"],
        manifest["documents"]["cover_letter"]["en-CH"],
    ]
    missing = [path for path in path_fields if not (ROOT / path).is_file()]
    if missing:
        raise ValidationError(f"ccvl.json: missing referenced files {', '.join(missing)}")
    if manifest["documents"]["cv"].get("presets") != [2, 3, 4]:
        raise ValidationError("ccvl.json: CV presets must be [2, 3, 4]")
    cover_letter = manifest["documents"]["cover_letter"]
    if cover_letter.get("paragraphs") != 5 or cover_letter.get("highlights") != 5:
        raise ValidationError("ccvl.json: cover-letter contract must be five paragraphs and five highlights")
    if manifest.get("career_vector", {}).get("import_mode") != "explicit-review":
        raise ValidationError("ccvl.json: CareerVector import must require explicit review")


def validate_applications() -> None:
    schema_path = ROOT / "schemas/application.schema.json"
    candidates = [
        ROOT / "templates/application.json",
        ROOT / "showcase/de-ch/application.json",
        ROOT / "showcase/en-ch/application.json",
    ]
    applications_root = ROOT / "applications"
    if applications_root.is_dir():
        candidates.extend(sorted(applications_root.glob("*/application.json")))

    for path in candidates:
        application = validate_json_file(path, schema_path)
        if path.parts[-3:-1] == ("showcase", "de-ch") and application["job"]["language"] != "de-CH":
            raise ValidationError(f"{path.relative_to(ROOT)}: expected de-CH language")
        if path.parts[-3:-1] == ("showcase", "en-ch") and application["job"]["language"] != "en-CH":
            raise ValidationError(f"{path.relative_to(ROOT)}: expected en-CH language")


def validate_profiles() -> None:
    schema_path = ROOT / "schemas/profile.schema.json"
    validate_json_file(ROOT / "templates/profile.json", schema_path)
    validate_json_file(ROOT / "showcase/profile.json", schema_path)


def parse_skill_frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"\A---\n(.*?)\n---\n", text, flags=re.DOTALL)
    if not match:
        raise ValidationError(f"{path.relative_to(ROOT)}: missing YAML frontmatter")
    result: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            raise ValidationError(f"{path.relative_to(ROOT)}: invalid frontmatter line {line!r}")
        key, value = line.split(":", 1)
        result[key.strip()] = value.strip()
    return result


def validate_skills() -> None:
    canonical_root = ROOT / ".agents/skills"
    adapters_root = ROOT / ".claude/skills"
    canonical = {path.parent.name: path for path in canonical_root.glob("*/SKILL.md")}
    adapters = {path.parent.name: path for path in adapters_root.glob("*/SKILL.md")}
    if not canonical:
        raise ValidationError("no canonical skills found under .agents/skills")
    if set(canonical) != set(adapters):
        raise ValidationError("canonical skills and Claude discovery adapters differ")

    for name, path in sorted(canonical.items()):
        frontmatter = parse_skill_frontmatter(path)
        if frontmatter.get("name") != name:
            raise ValidationError(f"{path.relative_to(ROOT)}: skill name must match directory")
        if not frontmatter.get("description"):
            raise ValidationError(f"{path.relative_to(ROOT)}: description is required")
        adapter = adapters[name].read_text(encoding="utf-8")
        expected_reference = f"../../../.agents/skills/{name}/SKILL.md"
        if expected_reference not in adapter:
            raise ValidationError(f"{adapters[name].relative_to(ROOT)}: must reference the canonical skill")


def main() -> int:
    try:
        validate_manifest()
        validate_profiles()
        validate_applications()
        validate_skills()
    except (KeyError, OSError, ValidationError) as exc:
        print(f"validation failed: {exc}", file=sys.stderr)
        return 1
    print("Workspace data and skill contracts are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
