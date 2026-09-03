#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
validation_dir="$(mktemp -d -t ccvl-check.XXXXXXXX)"
trap 'rm -rf -- "$validation_dir"' EXIT

cd "$repo_root"

scripts/doctor.sh >/dev/null
python3 scripts/validate_workspace.py
typstyle --check --line-width 120 cvl showcase
git diff --check

check_pdf() {
  local pdf="$1"
  local expected_pages="$2"
  local actual_pages
  local text_size

  actual_pages="$(pdfinfo "$pdf" | awk '/^Pages:/ { print $2 }')"
  if [[ "$actual_pages" != "$expected_pages" ]]; then
    printf '%s rendered %s pages; expected %s\n' "$pdf" "$actual_pages" "$expected_pages" >&2
    return 1
  fi

  text_size="$(pdftotext "$pdf" - | tr -d '[:space:]' | wc -c)"
  if ((text_size < 100)); then
    printf '%s has no usable text layer\n' "$pdf" >&2
    return 1
  fi

  if pdffonts "$pdf" | tail -n +3 | awk 'NF && $5 != "yes" { exit 1 }'; then
    :
  else
    printf '%s contains a font that is not embedded\n' "$pdf" >&2
    return 1
  fi
}

for locale in de-ch en-ch; do
  for pages in 2 3 4; do
    pdf="$validation_dir/cv-$locale-$pages.pdf"
    scripts/render.sh cv "$locale" "$pages" "showcase/$locale/application.json" "showcase/profile.json" "$pdf" >/dev/null
    check_pdf "$pdf" "$pages"
  done

  pdf="$validation_dir/cl-$locale.pdf"
  scripts/render.sh cl "$locale" "showcase/$locale/application.json" "showcase/profile.json" "$pdf" >/dev/null
  check_pdf "$pdf" 1
done

printf 'All data, source, CV, and cover-letter checks passed.\n'
