#!/usr/bin/env bash
# Linux-only secondary checks using Poppler and QPDF.
set -euo pipefail
export LC_ALL=C

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
validation_dir="$(mktemp -d "${TMPDIR:-/tmp}/ccvl-check.XXXXXXXX")"
trap 'rm -rf -- "$validation_dir"' EXIT

cd "$repo_root"

bash scripts/doctor.sh >/dev/null
bash scripts/check-fonts.sh
python3 scripts/validate_workspace.py
python3 -m unittest discover -s tests -p 'test_*.py'
bash tests/test_bootstrap.sh
for shell_script in scripts/*.sh; do
  bash -n "$shell_script"
done
typstyle --check --line-width 120 cvl showcase

profile_value() {
  python3 - "$1" <<'PY'
import json
import sys
from pathlib import Path

print(json.loads(Path("showcase/profile.json").read_text(encoding="utf-8"))[sys.argv[1]])
PY
}

public_name="$(profile_value name)"
public_email="$(profile_value email)"
public_phone="$(profile_value phone_label)"

check_pdf() {
  local pdf="$1"
  local expected_pages="$2"
  local require_image="${3:-no}"
  local actual_pages
  local extracted_text
  local pdf_info
  local text_size

  if ! qpdf --check "$pdf" >/dev/null; then
    printf '%s failed independent PDF structure validation\n' "$pdf" >&2
    return 1
  fi

  pdf_info="$(pdfinfo "$pdf" 2>"$validation_dir/pdfinfo-errors.txt")"
  if [[ -s "$validation_dir/pdfinfo-errors.txt" ]]; then
    while IFS= read -r diagnostic; do
      if [[ "$diagnostic" != 'Syntax Error: Suspects object is wrong type (boolean)' ]]; then
        printf '%s emitted an unexpected pdfinfo diagnostic: %s\n' "$pdf" "$diagnostic" >&2
        return 1
      fi
    done < "$validation_dir/pdfinfo-errors.txt"
  fi

  actual_pages="$(awk '/^Pages:/ { print $2 }' <<<"$pdf_info")"
  if [[ "$actual_pages" != "$expected_pages" ]]; then
    printf '%s rendered %s pages; expected %s\n' "$pdf" "$actual_pages" "$expected_pages" >&2
    return 1
  fi

  for metadata_rule in \
    '^Encrypted:[[:space:]]+no$' \
    '^Form:[[:space:]]+none$' \
    '^JavaScript:[[:space:]]+no$' \
    '^Page size:.*\(A4\)$'; do
    if ! grep -Eq "$metadata_rule" <<<"$pdf_info"; then
      printf '%s failed PDF metadata rule: %s\n' "$pdf" "$metadata_rule" >&2
      return 1
    fi
  done

  if ! pdfdetach -list "$pdf" | grep -Fxq '0 embedded files'; then
    printf '%s contains an unexpected embedded file\n' "$pdf" >&2
    return 1
  fi

  extracted_text="$(pdftotext "$pdf" -)"
  text_size="$(tr -d '[:space:]' <<<"$extracted_text" | wc -c)"
  if ((text_size < 100)); then
    printf '%s has no usable text layer\n' "$pdf" >&2
    return 1
  fi
  for literal in "$public_name" "$public_email" "$public_phone"; do
    if ! grep -Fq "$literal" <<<"$extracted_text"; then
      printf '%s is missing machine-readable contact text: %s\n' "$pdf" "$literal" >&2
      return 1
    fi
  done

  if pdffonts "$pdf" | tail -n +3 | awk 'NF && $5 != "yes" { exit 1 }'; then
    :
  else
    printf '%s contains a font that is not embedded\n' "$pdf" >&2
    return 1
  fi

  if [[ "$require_image" == yes ]] && ! pdfimages -list "$pdf" | awk 'NR > 2 && $3 == "image" { found = 1 } END { exit !found }'; then
    printf '%s is missing its rendered signature image\n' "$pdf" >&2
    return 1
  fi

  if pdffonts "$pdf" | tail -n +3 | awk '
    NF && ($1 !~ /^[A-Z]+[+]Archivo-/ || $5 != "yes" || $6 != "yes" || $7 != "yes") { exit 1 }
  '; then
    :
  else
    printf '%s contains a fallback, unembedded, unsubstituted, or unmapped font\n' "$pdf" >&2
    return 1
  fi
}

render_suite() {
  local destination="$1"
  local locale
  local pages

  for locale in de-ch en-ch; do
    for pages in 2 3 4; do
      bash scripts/render.sh cv \
        "$locale" \
        "$pages" \
        "showcase/$locale/application.json" \
        "showcase/profile.json" \
        "$destination/cv-$locale-$pages.pdf" >/dev/null
    done
    bash scripts/render.sh cl \
      "$locale" \
      "showcase/$locale/application.json" \
      "showcase/profile.json" \
      "$destination/cl-$locale.pdf" >/dev/null
  done
}

first_build="$validation_dir/first"
second_build="$validation_dir/second"
mkdir -p -- "$first_build" "$second_build"
render_suite "$first_build"
render_suite "$second_build"

for locale in de-ch en-ch; do
  for pages in 2 3 4; do
    pdf="$first_build/cv-$locale-$pages.pdf"
    check_pdf "$pdf" "$pages"
    cmp --silent "$pdf" "$second_build/cv-$locale-$pages.pdf" || {
      printf 'CV build is not byte-reproducible: %s %s pages\n' "$locale" "$pages" >&2
      exit 1
    }
    cmp --silent "$pdf" "cvl/cv/output/$locale/${pages}pager/cv.pdf" || {
      printf 'Tracked CV output is stale: %s %s pages\n' "$locale" "$pages" >&2
      exit 1
    }
  done

  pdf="$first_build/cl-$locale.pdf"
  check_pdf "$pdf" 1 yes
  cmp --silent "$pdf" "$second_build/cl-$locale.pdf" || {
    printf 'Cover-letter build is not byte-reproducible: %s\n' "$locale" >&2
    exit 1
  }
  cmp --silent "$pdf" "cvl/cl/output/$locale/cl.pdf" || {
    printf 'Tracked cover-letter output is stale: %s\n' "$locale" >&2
    exit 1
  }

  for pages in 2 3 4; do
    pdftoppm \
      -f 1 \
      -l 2 \
      -png \
      -r 72 \
      "$first_build/cv-$locale-$pages.pdf" \
      "$validation_dir/pages-$locale-$pages" >/dev/null 2>&1
  done
  for page in 1 2; do
    cmp --silent \
      "$validation_dir/pages-$locale-2-$page.png" \
      "$validation_dir/pages-$locale-3-$page.png" || {
      printf 'Shared CV page changed across presets: %s page %s (2 vs 3)\n' "$locale" "$page" >&2
      exit 1
    }
    cmp --silent \
      "$validation_dir/pages-$locale-2-$page.png" \
      "$validation_dir/pages-$locale-4-$page.png" || {
      printf 'Shared CV page changed across presets: %s page %s (2 vs 4)\n' "$locale" "$page" >&2
      exit 1
    }
  done
done

printf 'All data, source, skill, font, reproducibility, CV, and cover-letter checks passed.\n'
