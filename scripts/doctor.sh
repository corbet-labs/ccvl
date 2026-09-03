#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$repo_root/.cache/ccvl/bin:$PATH"
export UV_PROJECT_ENVIRONMENT="$repo_root/.cache/ccvl/venv"
export UV_CACHE_DIR="$repo_root/.cache/ccvl/uv-cache"
export UV_PYTHON_INSTALL_DIR="$repo_root/.cache/ccvl/python"

if ! command -v uv >/dev/null 2>&1; then
  printf 'uv is missing. Run bash ./ccvl bootstrap for the read-only setup plan.\n' >&2
  exit 1
fi

cd "$repo_root"
uv run \
  --frozen \
  --no-dev \
  --python "$(<"$repo_root/.python-version")" \
  python "$repo_root/scripts/doctor.py"
