#!/usr/bin/env bash
set -euo pipefail

required=(
  git
  git-lfs
  jq
  just
  pdfinfo
  pdffonts
  pdftoppm
  pdftotext
  python3
  rg
  typst
  typstyle
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

if ((${#missing[@]} > 0)); then
  printf '\nMissing required commands: %s\n' "${missing[*]}" >&2
  exit 1
fi

printf '\nccvl toolchain is ready.\n'
