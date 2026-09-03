#!/usr/bin/env python3
"""Validate the fixed CV slot layout and evidence-backed station plan."""

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
ID_PATTERN = r"[a-z0-9]+(?:[-_][a-z0-9]+)*"
FULL_ENTRY_PATTERN = re.compile(r"(?m)^\s*#cv-h\[")
BULLET_PATTERN = re.compile(r"(?m)^\s*#cv-b\[")
GROUP_PATTERN = re.compile(r"(?m)^\s*#cv-spacious-heading\[")
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


@dataclass(frozen=True)
class SourceEntry:
    identifier: str
    bullets: int
    offset: int


@dataclass(frozen=True)
class SourceLayout:
    station_ids: dict[int, tuple[str, ...]]
    project_ids: tuple[str, ...]
    competency_groups: tuple[tuple[str, ...], ...]


def contract() -> dict[str, Any]:
    return load_json(ROOT / "ccvl.json")["documents"]["cv"]["layout_contract"]


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
            raise ValidationError(
                f"{station_location}: page 1 accepts only truthfully experience-eligible "
                "stations in section 'experience'"
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
    page_one_limits = rules["page_1"]["entries"]
    if page_counts[1] < page_one_limits["minimum"]:
        problems.append(
            f"page 1 is underfilled: {page_counts[1]} stations; minimum {page_one_limits['minimum']}"
        )
    elif page_counts[1] > page_one_limits["maximum"]:
        problems.append(
            f"page 1 is overcrowded: {page_counts[1]} stations; maximum {page_one_limits['maximum']}"
        )

    page_two_entries = rules["page_2"]["entries"]
    if page_counts[2] < page_two_entries:
        problems.append(f"page 2 is underfilled: {page_counts[2]} stations; exactly {page_two_entries} required")
    elif page_counts[2] > page_two_entries:
        problems.append(f"page 2 is overcrowded: {page_counts[2]} stations; exactly {page_two_entries} required")
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


def _source_pages(path: Path, required: int) -> tuple[str, ...]:
    pages = tuple(path.read_text(encoding="utf-8").split(PAGE_BREAK))
    if len(pages) < required:
        raise ValidationError(
            f"{path.relative_to(ROOT)}: expected at least {required} CV page segments, found {len(pages)}"
        )
    return pages


def _marked_entries(path: Path, page: int, source_page: str, marker: str) -> tuple[SourceEntry, ...]:
    marker_pattern = re.compile(
        rf"(?m)^\s*// ccvl-{re.escape(marker)}: ({ID_PATTERN})\s*\n\s*#cv-h\["
    )
    matches = tuple(marker_pattern.finditer(source_page))
    heading_count = len(FULL_ENTRY_PATTERN.findall(source_page))
    if heading_count != len(matches):
        raise ValidationError(
            f"{path.relative_to(ROOT)}: page {page} has {heading_count} full entries but "
            f"{len(matches)} ccvl-{marker} markers"
        )

    entries: list[SourceEntry] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(source_page)
        entries.append(
            SourceEntry(
                identifier=match.group(1),
                bullets=len(BULLET_PATTERN.findall(source_page[match.end() : end])),
                offset=match.start(),
            )
        )
    return tuple(entries)


def typst_station_ids(path: Path) -> dict[int, tuple[str, ...]]:
    pages = _source_pages(path, 2)
    return {
        page: tuple(entry.identifier for entry in _marked_entries(path, page, pages[page - 1], "station"))
        for page in (1, 2)
    }


def count_typst_stations(path: Path) -> dict[int, int]:
    return {page: len(stations) for page, stations in typst_station_ids(path).items()}


def _require_entry_count(path: Path, page: int, entries: tuple[SourceEntry, ...], expected: int) -> None:
    if len(entries) != expected:
        raise ValidationError(
            f"{path.relative_to(ROOT)}: page {page} has {len(entries)} full entries; exactly {expected} required"
        )


def _require_bullet_count(
    path: Path, page: int, entries: tuple[SourceEntry, ...], expected: int, label: str
) -> None:
    invalid = tuple(entry for entry in entries if entry.bullets != expected)
    if invalid:
        details = ", ".join(f"{entry.identifier}={entry.bullets}" for entry in invalid)
        raise ValidationError(
            f"{path.relative_to(ROOT)}: page {page} {label} must each have exactly {expected} bullets; {details}"
        )


def validate_typst_layout(path: Path) -> SourceLayout:
    """Validate all fixed visual slots in one four-page CV source."""

    rules = contract()
    pages = _source_pages(path, 4)
    station_entries = {
        page: _marked_entries(path, page, pages[page - 1], "station") for page in (1, 2)
    }
    page_one_limits = rules["page_1"]["entries"]
    page_one_count = len(station_entries[1])
    if not page_one_limits["minimum"] <= page_one_count <= page_one_limits["maximum"]:
        raise ValidationError(
            f"{path.relative_to(ROOT)}: page 1 has {page_one_count} full entries; "
            f"allowed {page_one_limits['minimum']}–{page_one_limits['maximum']}"
        )

    page_two_rules = rules["page_2"]
    _require_entry_count(path, 2, station_entries[2], page_two_rules["entries"])
    _require_bullet_count(path, 2, station_entries[2], page_two_rules["bullets_per_entry"], "stations")

    project_entries = _marked_entries(path, 3, pages[2], "project")
    page_three_rules = rules["page_3"]
    _require_entry_count(path, 3, project_entries, page_three_rules["entries"])
    _require_bullet_count(path, 3, project_entries, page_three_rules["bullets_per_entry"], "projects")

    competency_entries = _marked_entries(path, 4, pages[3], "competency")
    page_four_rules = rules["page_4"]
    expected_competencies = page_four_rules["groups"] * page_four_rules["entries_per_group"]
    _require_entry_count(path, 4, competency_entries, expected_competencies)
    _require_bullet_count(
        path, 4, competency_entries, page_four_rules["bullets_per_entry"], "competency blocks"
    )

    marker_owners: dict[str, int] = {}
    for page, entries in (
        (1, station_entries[1]),
        (2, station_entries[2]),
        (3, project_entries),
        (4, competency_entries),
    ):
        for entry in entries:
            previous_page = marker_owners.get(entry.identifier)
            if previous_page is not None:
                raise ValidationError(
                    f"{path.relative_to(ROOT)}: entry marker {entry.identifier!r} appears on pages "
                    f"{previous_page} and {page}; every visible entry needs one unique owner"
                )
            marker_owners[entry.identifier] = page

    group_matches = tuple(GROUP_PATTERN.finditer(pages[3]))
    if len(group_matches) != page_four_rules["groups"]:
        raise ValidationError(
            f"{path.relative_to(ROOT)}: page 4 has {len(group_matches)} competency groups; "
            f"exactly {page_four_rules['groups']} required"
        )
    competency_groups: list[tuple[str, ...]] = []
    for index, group in enumerate(group_matches):
        end = group_matches[index + 1].start() if index + 1 < len(group_matches) else len(pages[3])
        identifiers = tuple(
            entry.identifier for entry in competency_entries if group.start() < entry.offset < end
        )
        if len(identifiers) != page_four_rules["entries_per_group"]:
            raise ValidationError(
                f"{path.relative_to(ROOT)}: page 4 competency group {index + 1} has {len(identifiers)} blocks; "
                f"exactly {page_four_rules['entries_per_group']} required"
            )
        competency_groups.append(identifiers)

    return SourceLayout(
        station_ids={
            page: tuple(entry.identifier for entry in station_entries[page]) for page in (1, 2)
        },
        project_ids=tuple(entry.identifier for entry in project_entries),
        competency_groups=tuple(competency_groups),
    )


def verify_source_counts(document: dict[str, Any], path: Path) -> SourceLayout:
    result = assess(document, str(GENERAL_PLAN.relative_to(ROOT)))
    expected_ids = {
        page: tuple(
            station["id"]
            for station in document["stations"]
            if station["page"] == page and station["status"] == "verified"
        )
        for page in (1, 2)
    }
    layout = validate_typst_layout(path)
    if layout.station_ids != expected_ids:
        raise ValidationError(
            f"{path.relative_to(ROOT)}: station source IDs {layout.station_ids} differ from plan {expected_ids}; "
            "add one ccvl-station marker per full entry and update the source or cvl/general/stations.json"
        )
    actual_counts = {page: len(ids) for page, ids in layout.station_ids.items()}
    if actual_counts != result.page_counts:
        raise ValidationError(f"{path.relative_to(ROOT)}: station counts differ from the validated plan")
    return layout


def validate_general(*, require_ready: bool) -> Assessment:
    document = load_plan(GENERAL_PLAN)
    result = assess(document, str(GENERAL_PLAN.relative_to(ROOT)))
    if require_ready and not result.ready:
        detail = "; ".join(result.problems)
        raise ValidationError(f"{detail}. Run ccvl profile-status and continue the profile interview")
    layouts = tuple(
        verify_source_counts(document, ROOT / "cvl" / "general" / locale / "cv.typ")
        for locale in ("de-ch", "en-ch")
    )
    if layouts[0].project_ids != layouts[1].project_ids:
        raise ValidationError("CV locales use different page-3 project IDs or ordering")
    if layouts[0].competency_groups != layouts[1].competency_groups:
        raise ValidationError("CV locales use different page-4 competency IDs, grouping, or ordering")
    return result


def format_report(result: Assessment) -> str:
    rules = contract()
    state = "READY" if result.ready else "NOT READY"
    page_one = rules["page_1"]["entries"]
    page_two = rules["page_2"]
    lines = [
        f"CV station plan: {state}",
        f"Page 1: {result.page_counts[1]} stations "
        f"(allowed {page_one['minimum']}–{page_one['maximum']}; target {page_one['target']})",
        f"Page 2: {result.page_counts[2]} stations "
        f"(fixed {page_two['entries']}; {page_two['bullets_per_entry']} bullets each)",
        f"Page 3: fixed {rules['page_3']['entries']} projects; "
        f"{rules['page_3']['bullets_per_entry']} bullets each",
        f"Page 4: fixed {rules['page_4']['groups']}×{rules['page_4']['entries_per_group']} "
        f"competency blocks; {rules['page_4']['bullets_per_entry']} keyword lines each",
        f"Unassigned candidates: {result.unassigned}",
    ]
    if result.problems:
        lines.append("Problems:")
        lines.extend(f"- {problem}" for problem in result.problems)
    if result.page_counts[1] < page_one["minimum"]:
        lines.append(
            "Next: ask for more experience and revisit paid, unpaid, independent, project, research, "
            "leadership, repair, teaching, and community work. Convert substantial work into a truthful "
            "experience station; never invent employment."
        )
        if result.experience_candidates:
            candidates = ", ".join(result.experience_candidates)
            lines.append(f"Existing page-1 candidates to assess or move, never duplicate: {candidates}")
    if result.page_counts[2] < page_two["entries"]:
        lines.append(
            "Next: ask about education, continuing development, credentials, research, publications, awards, "
            "communities, volunteering, and personal responsibility until page 2 has exactly ten stations."
        )
    if result.page_counts[1] > page_one["maximum"] or result.page_counts[2] > page_two["entries"]:
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
            layouts = tuple(
                verify_source_counts(document, ROOT / "cvl" / "general" / locale / "cv.typ")
                for locale in ("de-ch", "en-ch")
            )
            if layouts[0].project_ids != layouts[1].project_ids:
                raise ValidationError("CV locales use different page-3 project IDs or ordering")
            if layouts[0].competency_groups != layouts[1].competency_groups:
                raise ValidationError("CV locales use different page-4 competency IDs, grouping, or ordering")
    except (KeyError, OSError, ValidationError, ValueError) as exc:
        print(f"station plan failed: {exc}", file=sys.stderr)
        return 2
    print(format_report(result))
    return 0 if result.ready else 1


if __name__ == "__main__":
    raise SystemExit(main())
