"""Validate the ccvl manifest, profiles, and opportunity records."""

from __future__ import annotations

from . import ROOT, ValidationError, load_json
from .schema import validate_json_file


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
