#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bash scripts/check.sh

for private_path in applications evidence outcomes private sources submissions targets; do
  if [[ -e "$private_path" ]]; then
    printf 'Private downstream path exists in the public workspace: %s\n' "$private_path" >&2
    exit 1
  fi
done

if find . -path ./.git -prune -o -path ./.cache -prune -o -type l -print | grep -q .; then
  printf 'Symlinks require manual publication review:\n' >&2
  find . -path ./.git -prune -o -path ./.cache -prune -o -type l -print >&2
  exit 1
fi

if rg --files-with-matches --fixed-strings \
  'version https://git-lfs.github.com/spec/v1' \
  cvl; then
  printf 'Unresolved Git LFS pointer found in a required public asset.\n' >&2
  exit 1
fi

secret_pattern='-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}'
if rg --hidden \
  --glob '!.git/**' \
  --glob '!.cache/**' \
  --glob '!cvl/**/output/**' \
  --glob '!cvl/cl/assets/signature.png' \
  --glob '!cvl/shared/fonts/**' \
  --pcre2 -- "$secret_pattern" .; then
  printf 'Potential secret found; publication stopped.\n' >&2
  exit 1
fi

if rg --hidden \
  --glob '!.git/**' \
  --glob '!.cache/**' \
  --glob '!PUBLIC_IDENTIFIERS.md' \
  --glob '!scripts/public-check.sh' \
  -- '/home/richc|julian-corbet/applications|BEGIN OPENSSH PRIVATE KEY' .; then
  printf 'Private workspace or downstream identifier found; publication stopped.\n' >&2
  exit 1
fi

printf 'Public-boundary checks passed. Review PUBLIC_IDENTIFIERS.md before changing repository visibility.\n'
