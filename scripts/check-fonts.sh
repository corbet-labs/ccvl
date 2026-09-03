#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
font_root="$repo_root/cvl/shared/fonts"

expected_archivo=(
  Archivo-Bold.ttf
  Archivo-Italic.ttf
  Archivo-Medium.ttf
  Archivo-Regular.ttf
)

font_listing="$(
  cd "$repo_root"
  typst fonts --font-path cvl/shared/fonts --ignore-system-fonts --variants
)"

if ! grep -Fxq 'Archivo' <<<"$font_listing"; then
  printf 'Typst did not discover the bundled Archivo family.\n' >&2
  exit 1
fi

for filename in "${expected_archivo[@]}"; do
  path="$font_root/$filename"
  if ! file --brief -- "$path" | grep -Eq 'TrueType|OpenType'; then
    printf 'Bundled font is missing, unresolved, or invalid: %s\n' "$path" >&2
    exit 1
  fi
  if ! grep -Fq "cvl/shared/fonts/$filename" <<<"$font_listing"; then
    printf 'Typst did not load bundled font variant: %s\n' "$filename" >&2
    exit 1
  fi
done

archivo_variant_count="$(
  grep -Eo 'cvl/shared/fonts/Archivo-[A-Za-z]+\.ttf' <<<"$font_listing" |
    sort -u |
    wc -l
)"
if [[ "$archivo_variant_count" != "${#expected_archivo[@]}" ]]; then
  printf 'Expected %s Archivo variants; Typst found %s.\n' \
    "${#expected_archivo[@]}" "$archivo_variant_count" >&2
  exit 1
fi

printf 'Bundled Archivo family and all four variants are available.\n'
