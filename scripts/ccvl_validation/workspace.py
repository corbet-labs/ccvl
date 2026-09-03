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
    if minimum < 1 or maximum > 100:
        raise ValidationError(f"{location}: fill bounds must remain within 1–100")


def validate_fill_floor(line: dict[str, object], floor: dict[str, int], location: str) -> None:
    if (
        line["min_fill"] < floor["minimum"]
        or line["target_fill"] < floor["target"]
        or line["max_fill"] > floor["maximum"]
    ):
        raise ValidationError(f"{location}: line contract weakens the required fill floor or target")


def validate_line_contracts(application: dict[str, object], location: str, *, require_text: bool) -> None:
    summary = application["tailored_cv"]["summary"]
    for index, line in enumerate(summary, start=1):
        validate_line_contract(line, f"{location}.tailored_cv.summary[{index}]", require_text=require_text)

    paragraphs = application["tailored_cl"]["paragraphs"]
    contract = load_json(ROOT / "ccvl.json")["documents"]["cover_letter"]
    paragraph_contracts = contract["paragraphs"]
    if len(paragraphs) != len(paragraph_contracts):
        raise ValidationError(
            f"{location}.tailored_cl.paragraphs: expected {len(paragraph_contracts)} paragraphs, "
            f"found {len(paragraphs)}"
        )
    for paragraph_index, (paragraph, paragraph_contract) in enumerate(
        zip(paragraphs, paragraph_contracts, strict=True), start=1
    ):
        actual_lines = len(paragraph["lines"])
        line_contract = paragraph_contract["lines"]
        if not line_contract["minimum"] <= actual_lines <= line_contract["maximum"]:
            raise ValidationError(
                f"{location}.tailored_cl.paragraphs[{paragraph_index}] ({paragraph_contract['role']}): "
                f"expected {line_contract['minimum']}–{line_contract['maximum']} lines, found {actual_lines}"
            )
        for line_index, line in enumerate(paragraph["lines"], start=1):
            line_location = f"{location}.tailored_cl.paragraphs[{paragraph_index}].lines[{line_index}]"
            validate_line_contract(line, line_location, require_text=require_text)
            validate_fill_floor(line, contract["line_fill"]["body"], line_location)

    body_lines = sum(len(paragraph["lines"]) for paragraph in paragraphs)
    body_contract = contract["body_lines"]
    if not body_contract["minimum"] <= body_lines <= body_contract["maximum"]:
        raise ValidationError(
            f"{location}.tailored_cl.paragraphs: expected {body_contract['minimum']}–"
            f"{body_contract['maximum']} body lines, found {body_lines}"
        )
    for region in contract["paragraph_regions"]:
        start = region["paragraphs"][0] - 1
        end = region["paragraphs"][-1]
        actual_lines = sum(len(paragraph["lines"]) for paragraph in paragraphs[start:end])
        if not region["minimum"] <= actual_lines <= region["maximum"]:
            raise ValidationError(
                f"{location}.tailored_cl.paragraphs[{start + 1}:{end}]: "
                f"expected {region['minimum']}–{region['maximum']} shared lines, found {actual_lines}"
            )
    highlights = application["tailored_cl"]["highlights"]
    if len(highlights) != contract["highlights"]["count"]:
        raise ValidationError(
            f"{location}.tailored_cl.highlights: expected {contract['highlights']['count']} items, "
            f"found {len(highlights)}"
        )
    for index, line in enumerate(highlights, start=1):
        line_location = f"{location}.tailored_cl.highlights[{index}]"
        validate_line_contract(line, line_location, require_text=require_text)
        validate_fill_floor(line, contract["line_fill"]["highlight"], line_location)


def validate_manifest() -> None:
    manifest = load_json(ROOT / "ccvl.json")
    if manifest.get("format") != "ccvl-workspace" or manifest.get("schema_version") != 3:
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
        "paragraphs": [
            {"number": 1, "role": "positioning", "lines": {"minimum": 3, "target": 3, "maximum": 3}},
            {"number": 2, "role": "primary-evidence", "lines": {"minimum": 5, "target": 6, "maximum": 7}},
            {
                "number": 3,
                "role": "complementary-evidence",
                "lines": {"minimum": 5, "target": 6, "maximum": 7},
            },
            {"number": 4, "role": "differentiation", "lines": {"minimum": 5, "target": 6, "maximum": 7}},
            {"number": 5, "role": "target-fit", "lines": {"minimum": 5, "target": 6, "maximum": 7}},
            {"number": 6, "role": "warm-close", "lines": {"minimum": 2, "target": 3, "maximum": 3}},
        ],
        "paragraph_regions": [
            {"paragraphs": [2, 3], "minimum": 10, "target": 12, "maximum": 12, "preferred_totals": [10, 12]},
            {"paragraphs": [4, 5], "minimum": 10, "target": 12, "maximum": 12, "preferred_totals": [10, 12]},
            {
                "paragraphs": [2, 3, 4, 5],
                "minimum": 20,
                "target": 22,
                "maximum": 22,
                "preferred_totals": [20, 21, 22],
            },
        ],
        "body_lines": {"minimum": 25, "target": 28, "maximum": 28},
        "highlights": {"count": 5, "lines_each": 1, "position": "between-paragraphs-3-and-4"},
        "line_fill": {
            "body": {"minimum": 75, "target": 90, "maximum": 100},
            "highlight": {"minimum": 60, "target": 82, "maximum": 100},
        },
        "mirror_paragraphs": [1, 6],
        "keep_paragraphs_together": True,
        "justify_body": True,
        "vertical_rhythm": {
            "gap_pt": {"minimum": 12, "target": 20, "maximum": 30},
            "highlight_center_percent": {"minimum": 50, "target": 56, "maximum": 60},
        },
        "widow_or_orphan_lines": 0,
    }
    simplified = {
        "paragraphs": [
            {"number": item["number"], "role": item["role"], "lines": item["lines"]}
            for item in cover_letter.get("paragraphs", [])
        ],
        "paragraph_regions": cover_letter.get("paragraph_regions"),
        "body_lines": cover_letter.get("body_lines"),
        "highlights": {
            key: cover_letter.get("highlights", {}).get(key)
            for key in ("count", "lines_each", "position")
        },
        "line_fill": cover_letter.get("line_fill"),
        "mirror_paragraphs": cover_letter.get("mirror_paragraphs"),
        "keep_paragraphs_together": cover_letter.get("keep_paragraphs_together"),
        "justify_body": cover_letter.get("justify_body"),
        "vertical_rhythm": cover_letter.get("vertical_rhythm"),
        "widow_or_orphan_lines": cover_letter.get("widow_or_orphan_lines"),
    }
    if simplified != expected or any(not item.get("purpose", "").strip() for item in cover_letter["paragraphs"]):
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
