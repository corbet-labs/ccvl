"""Validate the ccvl manifest, profiles, and opportunity records."""

from __future__ import annotations

from . import ROOT, ValidationError, load_json
from .schema import validate_json_file


def validate_line_contract(line: dict[str, object], location: str, *, require_text: bool) -> None:
    text = line["text"]
    if require_text and (not isinstance(text, str) or not text.strip()):
        raise ValidationError(f"{location}.text: a rendered line cannot be empty")
    minimum = line["min_fill"]
    target = line["target_fill"]
    maximum = line["max_fill"]
    if not minimum <= target <= maximum:
        raise ValidationError(f"{location}: expected min_fill <= target_fill <= max_fill")


def validate_line_contracts(application: dict[str, object], location: str, *, require_text: bool) -> None:
    summary = application["tailored_cv"]["summary"]
    for index, line in enumerate(summary, start=1):
        validate_line_contract(line, f"{location}.tailored_cv.summary[{index}]", require_text=require_text)

    paragraphs = application["tailored_cl"]["paragraphs"]
    contract = load_json(ROOT / "ccvl.json")["documents"]["cover_letter"]
    body_lines = sum(len(paragraph["lines"]) for paragraph in paragraphs)
    body_contract = contract["body_lines"]
    if not body_contract["minimum"] <= body_lines <= body_contract["maximum"]:
        raise ValidationError(
            f"{location}.tailored_cl.paragraphs: expected {body_contract['minimum']}–"
            f"{body_contract['maximum']} body lines, found {body_lines}"
        )
    for region in contract["line_regions"]:
        start = region["paragraphs"][0] - 1
        end = region["paragraphs"][-1]
        actual_lines = sum(len(paragraph["lines"]) for paragraph in paragraphs[start:end])
        if not region["minimum"] <= actual_lines <= region["maximum"]:
            raise ValidationError(
                f"{location}.tailored_cl.paragraphs[{start + 1}:{end}]: "
                f"expected {region['minimum']}–{region['maximum']} shared lines, found {actual_lines}"
            )
    for paragraph_index, paragraph in enumerate(paragraphs, start=1):
        for line_index, line in enumerate(paragraph["lines"], start=1):
            validate_line_contract(
                line,
                f"{location}.tailored_cl.paragraphs[{paragraph_index}].lines[{line_index}]",
                require_text=require_text,
            )
    for index, line in enumerate(application["tailored_cl"]["highlights"], start=1):
        validate_line_contract(line, f"{location}.tailored_cl.highlights[{index}]", require_text=require_text)


def validate_manifest() -> None:
    manifest = load_json(ROOT / "ccvl.json")
    if manifest.get("format") != "ccvl-workspace" or manifest.get("schema_version") != 2:
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
    if manifest["documents"]["cv"].get("summary_lines") != 5:
        raise ValidationError("ccvl.json: every CV Summary must contain exactly five rendered lines")
    cover_letter = manifest["documents"]["cover_letter"]
    expected = {
        "paragraphs": 5,
        "highlights": 5,
        "body_lines": {"minimum": 14, "target": 15, "maximum": 16},
        "line_regions": [
            {"paragraphs": [1, 2, 3], "minimum": 8, "target": 9, "maximum": 10},
            {"paragraphs": [4, 5], "minimum": 5, "target": 6, "maximum": 7},
        ],
        "vertical_rhythm": {
            "gap_pt": {"minimum": 30, "target": 45, "maximum": 55},
            "highlight_center_percent": {"minimum": 56, "target": 61, "maximum": 67},
        },
    }
    if any(cover_letter.get(key) != value for key, value in expected.items()):
        raise ValidationError("ccvl.json: cover-letter line and structure contract changed")


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
        validate_line_contracts(
            application,
            str(path.relative_to(ROOT)),
            require_text=path != ROOT / "templates" / "application.json",
        )
        if path.parts[-3:-1] == ("showcase", "de-ch") and application["job"]["language"] != "de-CH":
            raise ValidationError(f"{path.relative_to(ROOT)}: expected de-CH language")
        if path.parts[-3:-1] == ("showcase", "en-ch") and application["job"]["language"] != "en-CH":
            raise ValidationError(f"{path.relative_to(ROOT)}: expected en-CH language")


def validate_profiles() -> None:
    schema_path = ROOT / "schemas/profile.schema.json"
    validate_json_file(ROOT / "templates/profile.json", schema_path)
    validate_json_file(ROOT / "showcase/profile.json", schema_path)
