#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
font_path="$repo_root/cvl/shared/fonts"
creation_timestamp="${SOURCE_DATE_EPOCH:-0}"

usage() {
  cat <<'EOF'
Usage:
  scripts/render.sh all
  scripts/render.sh cv <de-ch|en-ch> <2|3|4> [application.json] [profile.json] [output.pdf]
  scripts/render.sh cl <de-ch|en-ch> [application.json] [profile.json] [output.pdf]
  scripts/render.sh application <application.json> <de-ch|en-ch> <2|3|4> [profile.json]
EOF
}

normalize_locale() {
  case "$1" in
    de | de-ch) printf 'de-ch\n' ;;
    en | en-ch) printf 'en-ch\n' ;;
    *)
      printf 'Unsupported locale: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

default_application() {
  case "$1" in
    de-ch) printf 'showcase/de-ch/application.json\n' ;;
    en-ch) printf 'showcase/en-ch/application.json\n' ;;
  esac
}

canonical_path() {
  local requested="$1"
  python3 - "$repo_root" "$requested" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
requested = Path(sys.argv[2])
path = requested.resolve(strict=True) if requested.is_absolute() else (root / requested).resolve(strict=True)
print(path)
PY
}

typst_path() {
  local requested="$1"
  local absolute

  absolute="$(canonical_path "$requested")"

  case "$absolute" in
    "$repo_root"/*) printf '/%s\n' "${absolute#"$repo_root"/}" ;;
    *)
      printf 'Input must be inside the ccvl workspace: %s\n' "$requested" >&2
      return 1
      ;;
  esac
}

host_path() {
  canonical_path "$1"
}

compile_pdf() {
  local source="$1"
  local output="$2"
  local diagnostics
  local status=0
  shift 2

  mkdir -p -- "$(dirname -- "$output")"
  diagnostics="$(mktemp "${TMPDIR:-/tmp}/ccvl-typst.XXXXXXXX")"
  typst compile \
    --root "$repo_root" \
    --font-path "$font_path" \
    --ignore-system-fonts \
    --creation-timestamp "$creation_timestamp" \
    "$@" \
    "$source" \
    "$output" \
    2> >(tee "$diagnostics" >&2) || status=$?

  if ((status != 0)); then
    rm -f -- "$diagnostics"
    return "$status"
  fi
  if [[ -s "$diagnostics" ]]; then
    printf 'Typst emitted diagnostics; refusing a fallback render.\n' >&2
    rm -f -- "$diagnostics"
    return 1
  fi
  rm -f -- "$diagnostics"
}

render_cv() {
  local locale
  locale="$(normalize_locale "$1")"
  local pages="$2"
  local application="${3:-$(default_application "$locale")}"
  local profile="${4:-showcase/profile.json}"
  local output="${5:-$repo_root/cvl/cv/output/$locale/${pages}pager/cv.pdf}"

  case "$pages" in
    2 | 3 | 4) ;;
    *)
      printf 'CV pages must be 2, 3, or 4: %s\n' "$pages" >&2
      return 1
      ;;
  esac

  compile_pdf \
    "$repo_root/cvl/cv/$locale/main.typ" \
    "$output" \
    --input "cv-pages=$pages" \
    --input "application=$(typst_path "$application")" \
    --input "profile=$(typst_path "$profile")"

  printf 'Rendered %s\n' "$output"
}

render_cl() {
  local locale
  locale="$(normalize_locale "$1")"
  local application="${2:-$(default_application "$locale")}"
  local profile="${3:-showcase/profile.json}"
  local output="${4:-$repo_root/cvl/cl/output/$locale/cl.pdf}"

  compile_pdf \
    "$repo_root/cvl/cl/$locale/main.typ" \
    "$output" \
    --input "application=$(typst_path "$application")" \
    --input "profile=$(typst_path "$profile")"

  printf 'Rendered %s\n' "$output"
}

render_all() {
  local locale
  local pages

  for locale in de-ch en-ch; do
    for pages in 2 3 4; do
      render_cv "$locale" "$pages"
    done
    render_cl "$locale"
  done
}

render_application() {
  local application="$1"
  local locale
  locale="$(normalize_locale "$2")"
  local pages="$3"
  local profile="${4:-showcase/profile.json}"
  local job_id

  job_id="$(python3 - "$(host_path "$application")" <<'PY'
import json
import re
import sys
from pathlib import Path

job_id = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["job"]["id"]
if not isinstance(job_id, str) or re.fullmatch(r"[A-Za-z0-9_-]+", job_id) is None:
    raise SystemExit("application job.id must contain only ASCII letters, numbers, hyphens, or underscores")
print(job_id)
PY
)"
  render_cv "$locale" "$pages" "$application" "$profile" "$repo_root/out/$job_id/cv.pdf"
  render_cl "$locale" "$application" "$profile" "$repo_root/out/$job_id/cl.pdf"
}

case "${1:-}" in
  all)
    [[ $# -eq 1 ]] || { usage >&2; exit 2; }
    render_all
    ;;
  cv)
    [[ $# -ge 3 && $# -le 6 ]] || { usage >&2; exit 2; }
    render_cv "$2" "$3" "${4:-}" "${5:-}" "${6:-}"
    ;;
  cl)
    [[ $# -ge 2 && $# -le 5 ]] || { usage >&2; exit 2; }
    render_cl "$2" "${3:-}" "${4:-}" "${5:-}"
    ;;
  application)
    [[ $# -ge 4 && $# -le 5 ]] || { usage >&2; exit 2; }
    render_application "$2" "$3" "$4" "${5:-}"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
