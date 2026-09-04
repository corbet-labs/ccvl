#!/usr/bin/env bash

# Values are consumed by scripts that source this file.
# shellcheck disable=SC2034

tool_assets_file="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tool-assets.csv"

ccvl_select_rustup_asset() {
  local requested_platform="$1"
  local tool version platform asset sha256 url

  while IFS=, read -r tool version platform asset sha256 url; do
    if [[ "$tool" == rustup-init && "$platform" == "$requested_platform" ]]; then
      CCVL_RUSTUP_VERSION="$version"
      CCVL_RUSTUP_ASSET="$asset"
      CCVL_RUSTUP_SHA256="$sha256"
      CCVL_RUSTUP_URL="$url"
      return 0
    fi
  done < "$tool_assets_file"
  return 1
}
