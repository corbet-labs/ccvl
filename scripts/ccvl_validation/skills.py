"""Validate canonical skills, adapters, and behavioural test cases."""

from __future__ import annotations

import re
from pathlib import Path

from . import ROOT, ValidationError, load_json


def parse_frontmatter(path: Path) -> dict[str, str]:
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
    declared = load_json(ROOT / "ccvl.json").get("skills")
    if not isinstance(declared, list) or not declared or len(declared) != len(set(declared)):
        raise ValidationError("ccvl.json: skills must be a non-empty array without duplicates")
    canonical = {path.parent.name: path for path in (ROOT / ".agents/skills").glob("*/SKILL.md")}
    adapters = {path.parent.name: path for path in (ROOT / ".claude/skills").glob("*/SKILL.md")}
    if set(declared) != set(canonical):
        raise ValidationError("ccvl.json skill manifest and canonical skills differ")
    if set(canonical) != set(adapters):
        raise ValidationError("canonical skills and Claude discovery adapters differ")

    for name, path in sorted(canonical.items()):
        frontmatter = parse_frontmatter(path)
        if frontmatter.get("name") != name or set(frontmatter) != {"name", "description"}:
            raise ValidationError(f"{path.relative_to(ROOT)}: invalid canonical frontmatter")
        if not frontmatter["description"] or len(frontmatter["description"]) > 1024:
            raise ValidationError(f"{path.relative_to(ROOT)}: invalid description")
        if not re.fullmatch(r"[a-z0-9-]{1,64}", name):
            raise ValidationError(f"{path.relative_to(ROOT)}: invalid skill name")
        adapter = adapters[name].read_text(encoding="utf-8")
        adapter_frontmatter = parse_frontmatter(adapters[name])
        if adapter_frontmatter.get("name") != name or not adapter_frontmatter.get("description"):
            raise ValidationError(f"{adapters[name].relative_to(ROOT)}: invalid adapter frontmatter")
        reference = f"../../../.agents/skills/{name}/SKILL.md"
        if adapter.count(reference) != 1:
            raise ValidationError(f"{adapters[name].relative_to(ROOT)}: must reference the canonical skill once")


def validate_skill_cases() -> None:
    document = load_json(ROOT / "tests/skill-cases.json")
    if document.get("schema_version") != 1 or not isinstance(document.get("instruction"), str):
        raise ValidationError("tests/skill-cases.json: unsupported or incomplete document")
    cases = document.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValidationError("tests/skill-cases.json: cases must be a non-empty array")

    case_ids: set[str] = set()
    case_skills: list[str] = []
    case_keys = {"id", "skill", "scenario", "options", "required", "forbidden"}
    for case in cases:
        if not isinstance(case, dict) or set(case) != case_keys:
            raise ValidationError("tests/skill-cases.json: invalid case contract")
        case_id = case["id"]
        if not isinstance(case_id, str) or not re.fullmatch(r"[a-z0-9-]+", case_id) or case_id in case_ids:
            raise ValidationError("tests/skill-cases.json: invalid or duplicate case id")
        case_ids.add(case_id)
        case_skills.append(case["skill"])
        if not isinstance(case["scenario"], str) or not case["scenario"].strip():
            raise ValidationError(f"tests/skill-cases.json: {case_id} has no scenario")

        options = case["options"]
        if not isinstance(options, list) or len(options) < 4:
            raise ValidationError(f"tests/skill-cases.json: {case_id} needs at least four options")
        option_ids = [option.get("id") for option in options if isinstance(option, dict)]
        if len(option_ids) != len(options) or len(option_ids) != len(set(option_ids)):
            raise ValidationError(f"tests/skill-cases.json: {case_id} has invalid or duplicate options")
        for option in options:
            if set(option) != {"id", "text"} or not re.fullmatch(r"[a-z0-9-]+", option["id"]):
                raise ValidationError(f"tests/skill-cases.json: {case_id} has an invalid option")
            if not isinstance(option["text"], str) or not option["text"].strip():
                raise ValidationError(f"tests/skill-cases.json: {case_id} has an empty option")

        required, forbidden = case["required"], case["forbidden"]
        if not isinstance(required, list) or not required or not isinstance(forbidden, list) or not forbidden:
            raise ValidationError(f"tests/skill-cases.json: {case_id} needs required and forbidden options")
        if not set(required).issubset(option_ids) or not set(forbidden).issubset(option_ids):
            raise ValidationError(f"tests/skill-cases.json: {case_id} references an unknown answer option")
        if set(required) & set(forbidden):
            raise ValidationError(f"tests/skill-cases.json: {case_id} has contradictory answer keys")

    declared = load_json(ROOT / "ccvl.json")["skills"]
    if set(case_skills) != set(declared):
        raise ValidationError("tests/skill-cases.json: cases must cover every declared skill")
    if list(dict.fromkeys(case_skills)) != declared:
        raise ValidationError("tests/skill-cases.json: first skill cases must follow manifest order")
