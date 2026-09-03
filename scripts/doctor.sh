#!/usr/bin/env bash
set -euo pipefail

required=(
  cmp
  file
  pdfdetach
  pdfinfo
  pdfimages
  pdffonts
  pdftoppm
  pdftotext
  python3
  qpdf
  rg
  typst
  typstyle
)

optional=(
  git
  just
)

missing=()

for command_name in "${required[@]}"; do
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '%-10s %s\n' "$command_name" "$(command -v "$command_name")"
  else
    printf '%-10s %s\n' "$command_name" "MISSING"
    missing+=("$command_name")
  fi
done

for command_name in "${optional[@]}"; do
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '%-10s %s (optional)\n' "$command_name" "$(command -v "$command_name")"
  else
    printf '%-10s %s\n' "$command_name" "MISSING (optional)"
  fi
done

if ((${#missing[@]} > 0)); then
  printf '\nMissing required commands: %s\n' "${missing[*]}" >&2
  exit 1
fi

bash "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/check-tool-versions.sh"
printf '\nccvl toolchain is ready.\n'
