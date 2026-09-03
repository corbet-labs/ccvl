#!/usr/bin/env python3
"""Validate CV station coverage and keep two-page layouts intentionally full."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from ccvl_validation import ROOT, ValidationError, load_json
from ccvl_validation.schema import validate_json_file


GENERAL_PLAN = ROOT / "cvl" / "general" / "stations.json"
STATION_SCHEMA = ROOT / "schemas" / "stations.schema.json"
STATION_PATTERN = re.compile(
    r"(?m)^\s*// ccvl-station: ([a-z0-9]+(?:[-_][a-z0-9]+)*)\s*\n\s*#cv-h\["
)
FULL_STATION_PATTERN = re.compile(r"(?m)^\s*#cv-h\[")
PAGE_BREAK = "#cv-pagebreak()"


@dataclass(frozen=True)
class Assessment:
    page_counts: dict[int, int]
    unassigned: int
    unresolved_assigned: tuple[str, ...]
    experience_candidates: tuple[str, ...]
    problems: tuple[str, ...]

    @property
    def ready(self) -> bool:
        return not self.problems


def contract() -> dict[str, Any]:
    return load_json(ROOT / "ccvl.json")["documents"]["cv"]["station_contract"]


def validate_semantics(document: dict[str, Any], location: str) -> None:
    if document["stations"] and not document["updated"]:
        raise ValidationError(f"{location}.updated: a non-empty station plan needs a review date")
    station_ids: set[str] = set()
    fact_owners: dict[str, str] = {}
    for index, station in enumerate(document["stations"], start=1):
        station_location = f"{location}.stations[{index}]"
        station_id = station["id"]
        if station_id in station_ids:
            raise ValidationError(f"{station_location}.id: duplicate station id {station_id!r}")
        station_ids.add(station_id)

        assigned = station["page"] is not None
        if assigned != bool(station["section"].strip()):
            raise ValidationError(f"{station_location}: page and section must be assigned together")
        invalid_page_one = station["section"] != "experience" or not station["experience_eligible"]
        if station["page"] == 1 and invalid_page_one:
            detail = "page 1 accepts only truthfully experience-eligible stations in section 'experience'"
            raise ValidationError(
                f"{station_location}: {detail}"
            )
        if station["status"] == "verified":
            if not station["label"].strip():
                raise ValidationError(f"{station_location}.label: a verified station needs a label")
            if not station["anchor"].strip():
                raise ValidationError(f"{station_location}.anchor: a verified station needs context or a period")
            if not station["facts"]:
                raise ValidationError(f"{station_location}.facts: a verified station needs at least one fact")
            if not station["source_refs"] or any(not item.strip() for item in station["source_refs"]):
                raise ValidationError(f"{station_location}.source_refs: a verified station needs provenance")

        for fact_index, fact in enumerate(station["facts"], start=1):
            if not fact["text"].strip():
                raise ValidationError(f"{station_location}.facts[{fact_index}].text: fact text cannot be empty")
            fact_id = fact["id"]
            if fact_id in fact_owners:
                raise ValidationError(
                    f"{station_location}.facts[{fact_index}].id: fact {fact_id!r} already belongs to "
                    f"station {fact_owners[fact_id]!r}; MECE assignment requires one owner"
                )
            fact_owners[fact_id] = station_id


def assess(document: dict[str, Any], location: str = "station-plan") -> Assessment:
    validate_semantics(document, location)
    rules = contract()
    page_counts = {1: 0, 2: 0}
    unresolved_assigned: list[str] = []
    experience_candidates: list[str] = []
    unassigned = 0

    for station in document["stations"]:
        if station["page"] is None:
            unassigned += 1
        elif station["status"] == "verified":
            page_counts[station["page"]] += 1
        else:
            unresolved_assigned.append(station["id"])
        if station["experience_eligible"] and station["page"] != 1:
            experience_candidates.append(station["id"])

    problems: list[str] = []
    for page in (1, 2):
        count = page_counts[page]
        limits = rules[f"page_{page}"]
        if count < limits["minimum"]:
            problems.append(f"page {page} is underfilled: {count} stations; minimum {limits['minimum']}")
        elif count > limits["maximum"]:
            problems.append(f"page {page} is overcrowded: {count} stations; maximum {limits['maximum']}")
    if page_counts[2] < page_counts[1]:
        problems.append(
            f"page 2 trails page 1: {page_counts[2]} stations versus {page_counts[1]}; "
            "the supporting page must contain at least as many"
        )
    if unresolved_assigned:
        problems.append("assigned stations are not verified: " + ", ".join(unresolved_assigned))

    return Assessment(
        page_counts=page_counts,
        unassigned=unassigned,
        unresolved_assigned=tuple(unresolved_assigned),
        experience_candidates=tuple(experience_candidates),
        problems=tuple(problems),
    )


def load_plan(path: Path) -> dict[str, Any]:
    return validate_json_file(path.resolve(strict=True), STATION_SCHEMA)


def typst_station_ids(path: Path) -> dict[int, tuple[str, ...]]:
    source = path.read_text(encoding="utf-8")
    pages = source.split(PAGE_BREAK)
    if len(pages) < 2:
        raise ValidationError(f"{path.relative_to(ROOT)}: expected a page break after each of the first two CV pages")
    result: dict[int, tuple[str, ...]] = {}
    for page, source_page in ((1, pages[0]), (2, pages[1])):
        station_ids = tuple(STATION_PATTERN.findall(source_page))
        heading_count = len(FULL_STATION_PATTERN.findall(source_page))
        if heading_count != len(station_ids):
            raise ValidationError(
                f"{path.relative_to(ROOT)}: page {page} has {heading_count} full entries but "
                f"{len(station_ids)} ccvl-station markers"
            )
        result[page] = station_ids
    return result


def count_typst_stations(path: Path) -> dict[int, int]:
    return {page: len(stations) for page, stations in typst_station_ids(path).items()}


def verify_source_counts(document: dict[str, Any], path: Path) -> None:
    result = assess(document, str(GENERAL_PLAN.relative_to(ROOT)))
    expected_ids = {
        page: tuple(
            station["id"]
            for station in document["stations"]
            if station["page"] == page and station["status"] == "verified"
        )
        for page in (1, 2)
    }
    actual_ids = typst_station_ids(path)
    if actual_ids != expected_ids:
        raise ValidationError(
            f"{path.relative_to(ROOT)}: station source IDs {actual_ids} differ from plan {expected_ids}; "
            "add one ccvl-station marker per full entry and update the source or cvl/general/stations.json"
        )
    actual_counts = {page: len(ids) for page, ids in actual_ids.items()}
    if actual_counts != result.page_counts:
        raise ValidationError(f"{path.relative_to(ROOT)}: station counts differ from the validated plan")


def validate_general(*, require_ready: bool) -> Assessment:
    document = load_plan(GENERAL_PLAN)
    result = assess(document, str(GENERAL_PLAN.relative_to(ROOT)))
    if require_ready and not result.ready:
        detail = "; ".join(result.problems)
        raise ValidationError(f"{detail}. Run ccvl profile-status and continue the profile interview")
    for locale in ("de-ch", "en-ch"):
        verify_source_counts(document, ROOT / "cvl" / "general" / locale / "cv.typ")
    return result


def format_report(result: Assessment) -> str:
    rules = contract()
    state = "READY" if result.ready else "NOT READY"
    lines = [f"CV station plan: {state}"]
    for page in (1, 2):
        limits = rules[f"page_{page}"]
        lines.append(
            f"Page {page}: {result.page_counts[page]} stations "
            f"(allowed {limits['minimum']}–{limits['maximum']}; target {limits['target']})"
        )
    lines.append(f"Unassigned candidates: {result.unassigned}")
    if result.problems:
        lines.append("Problems:")
        lines.extend(f"- {problem}" for problem in result.problems)
    if result.page_counts[1] < rules["page_1"]["minimum"]:
        lines.append(
            "Next: ask for more experience and revisit paid, unpaid, independent, project, research, "
            "leadership, repair, teaching, and community work. Convert substantial work into a truthful "
            "experience station; never invent employment."
        )
        if result.experience_candidates:
            candidates = ", ".join(result.experience_candidates)
            lines.append(f"Existing page-1 candidates to assess or move, never duplicate: {candidates}")
    if result.page_counts[2] < rules["page_2"]["minimum"]:
        lines.append(
            "Next: ask about education, continuing development, credentials, research, publications, awards, "
            "communities, volunteering, and personal responsibility."
        )
    if result.page_counts[1] > rules["page_1"]["maximum"] or result.page_counts[2] > rules["page_2"]["maximum"]:
        lines.append("Next: rank, merge, move, or leave stations unassigned; do not duplicate facts across sections.")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", nargs="?", default=str(GENERAL_PLAN.relative_to(ROOT)))
    parser.add_argument("--verify-sources", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        path = Path(args.plan)
        path = path if path.is_absolute() else ROOT / path
        document = load_plan(path)
        result = assess(document, str(path.relative_to(ROOT)))
        if args.verify_sources and result.ready:
            for locale in ("de-ch", "en-ch"):
                verify_source_counts(document, ROOT / "cvl" / "general" / locale / "cv.typ")
    except (KeyError, OSError, ValidationError, ValueError) as exc:
        print(f"station plan failed: {exc}", file=sys.stderr)
        return 2
    print(format_report(result))
    return 0 if result.ready else 1


if __name__ == "__main__":
    raise SystemExit(main())
