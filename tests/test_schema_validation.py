#!/usr/bin/env python3
"""Exercise every JSON Schema feature used by ccvl."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from ccvl_validation import ValidationError  # noqa: E402
from ccvl_validation.schema import validate_schema  # noqa: E402


SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["name", "count", "values", "state"],
    "properties": {
        "name": {"type": "string", "pattern": "^[a-z-]+$"},
        "count": {"type": "integer", "minimum": 1},
        "values": {
            "type": "array",
            "minItems": 1,
            "maxItems": 2,
            "items": {"$ref": "#/$defs/value"},
        },
        "state": {"enum": ["ready", "blocked"]},
        "empty": {"const": None},
    },
    "$defs": {"value": {"type": ["string", "null"]}},
}


class SchemaValidationTests(unittest.TestCase):
    def assert_invalid(self, value: object) -> None:
        with self.assertRaises(ValidationError):
            validate_schema(value, SCHEMA, SCHEMA, "fixture")

    def test_valid_nested_document(self) -> None:
        validate_schema(
            {"name": "valid-name", "count": 1, "values": ["one", None], "state": "ready", "empty": None},
            SCHEMA,
            SCHEMA,
            "fixture",
        )

    def test_missing_required_field_is_rejected(self) -> None:
        self.assert_invalid({"name": "valid", "count": 1, "values": ["one"]})

    def test_unknown_field_is_rejected(self) -> None:
        self.assert_invalid({"name": "valid", "count": 1, "values": ["one"], "state": "ready", "other": 1})

    def test_boolean_is_not_an_integer(self) -> None:
        self.assert_invalid({"name": "valid", "count": True, "values": ["one"], "state": "ready"})

    def test_pattern_minimum_enum_and_array_bounds_are_enforced(self) -> None:
        invalid_documents = [
            {"name": "NOT VALID", "count": 1, "values": ["one"], "state": "ready"},
            {"name": "valid", "count": 0, "values": ["one"], "state": "ready"},
            {"name": "valid", "count": 1, "values": [], "state": "ready"},
            {"name": "valid", "count": 1, "values": ["one", "two", "three"], "state": "ready"},
            {"name": "valid", "count": 1, "values": ["one"], "state": "unknown"},
        ]
        for document in invalid_documents:
            with self.subTest(document=document):
                self.assert_invalid(document)


if __name__ == "__main__":
    unittest.main()
