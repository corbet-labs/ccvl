#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$repo_root/.cache/ccvl/bin:$PATH"
export UV_PROJECT_ENVIRONMENT="$repo_root/.cache/ccvl/venv"
export UV_CACHE_DIR="$repo_root/.cache/ccvl/uv-cache"
export UV_PYTHON_INSTALL_DIR="$repo_root/.cache/ccvl/python"

cd "$repo_root"
exec uv run \
  --frozen \
  --no-dev \
  --python "$(<"$repo_root/.python-version")" \
  python "$repo_root/scripts/render.py" "$@"
