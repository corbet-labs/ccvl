#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/tool-versions.sh
source "$repo_root/scripts/tool-versions.sh"

typst_version="$(typst --version 2>&1)"
typstyle_version="$(typstyle --version 2>&1)"

if [[ "$typst_version" != *"typst $CCVL_TYPST_VERSION"* ]]; then
  printf 'Typst %s is required; found: %s\n' "$CCVL_TYPST_VERSION" "$typst_version" >&2
  exit 1
fi
if [[ "$typstyle_version" != *"$CCVL_TYPSTYLE_VERSION"* ]]; then
  printf 'Typstyle %s is required; found: %s\n' "$CCVL_TYPSTYLE_VERSION" "$typstyle_version" >&2
  exit 1
fi

printf 'Pinned Typst and Typstyle versions are active.\n'
