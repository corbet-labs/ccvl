"""The small JSON Schema subset used by ccvl's checked-in contracts."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from . import ROOT, ValidationError, load_json


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


def validate_schema(value: Any, schema: dict[str, Any], schema_root: dict[str, Any], location: str) -> None:
    if "$ref" in schema:
        validate_schema(value, resolve_ref(schema_root, schema["$ref"]), schema_root, location)
        return
    if "const" in schema and value != schema["const"]:
        raise ValidationError(f"{location}: expected constant {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValidationError(f"{location}: {value!r} is not in {schema['enum']!r}")

    expected_types = schema.get("type")
    if expected_types is not None:
        expected_types = [expected_types] if isinstance(expected_types, str) else expected_types
        if not any(value_has_type(value, expected) for expected in expected_types):
            raise ValidationError(f"{location}: expected type {' or '.join(expected_types)}")

    if isinstance(value, dict):
        missing = [field for field in schema.get("required", []) if field not in value]
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
        for index, child in enumerate(value):
            if "items" in schema:
                validate_schema(child, schema["items"], schema_root, f"{location}[{index}]")

    if isinstance(value, int) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            raise ValidationError(f"{location}: value is below minimum {schema['minimum']}")
    if isinstance(value, str) and "pattern" in schema and re.fullmatch(schema["pattern"], value) is None:
        raise ValidationError(f"{location}: value does not match {schema['pattern']!r}")


def validate_json_file(path: Path, schema_path: Path) -> dict[str, Any]:
    schema = load_json(schema_path)
    value = load_json(path)
    validate_schema(value, schema, schema, str(path.relative_to(ROOT)))
    return value
