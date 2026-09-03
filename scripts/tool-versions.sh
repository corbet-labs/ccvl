#!/usr/bin/env bash

# Values are consumed by scripts that source this file.
# shellcheck disable=SC2034

tool_assets_file="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tool-assets.csv"

ccvl_tool_version() {
  local requested_tool="$1"
  awk -F, -v tool="$requested_tool" 'NR > 1 && $1 == tool { print $2; exit }' "$tool_assets_file"
}

ccvl_select_tool_asset() {
  local requested_tool="$1"
  local requested_platform="$2"
  local tool version platform asset sha256 kind url

  while IFS=, read -r tool version platform asset sha256 kind url; do
    if [[ "$tool" == "$requested_tool" && "$platform" == "$requested_platform" ]]; then
      CCVL_TOOL_NAME="$tool"
      CCVL_TOOL_VERSION="$version"
      CCVL_TOOL_ASSET="$asset"
      CCVL_TOOL_SHA256="$sha256"
      CCVL_TOOL_KIND="$kind"
      CCVL_TOOL_URL="$url"
      return 0
    fi
  done < "$tool_assets_file"
  return 1
}

CCVL_TYPST_VERSION="$(ccvl_tool_version typst)"
CCVL_TYPSTYLE_VERSION="$(ccvl_tool_version typstyle)"
CCVL_UV_VERSION="$(ccvl_tool_version uv)"
