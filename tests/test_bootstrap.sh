#!/usr/bin/env bash
set -euo pipefail

# Keep the simulated probe matrix independent from the caller's environment.
export CCVL_BOOTSTRAP_FORCE_LOCAL=0

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/ccvl-bootstrap-test.XXXXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

create_fake() {
  local directory="$1"
  local name="$2"
  local output="${3:-}"
  printf '#!/bin/sh\nprintf "%%s\\n" %q\n' "$output" > "$directory/$name"
  chmod 0755 "$directory/$name"
}

complete_bin="$scratch/complete"
empty_bin="$scratch/empty"
partial_bin="$scratch/partial"
mkdir -p "$complete_bin" "$empty_bin" "$partial_bin"

for command_name in curl xz; do
  create_fake "$complete_bin" "$command_name"
  create_fake "$partial_bin" "$command_name"
done
create_fake "$complete_bin" typst 'typst 0.15.1'
create_fake "$complete_bin" typstyle 'Version: 0.15.1'
create_fake "$complete_bin" uv 'uv 0.12.9'
create_fake "$partial_bin" typst 'typst 0.14.0'
create_fake "$partial_bin" typstyle 'Version: 0.15.1'
create_fake "$partial_bin" uv 'uv 0.12.9'

complete_output="$(
  CCVL_BOOTSTRAP_TESTING=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$complete_bin" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
  CCVL_BOOTSTRAP_TEST_MANAGER=apt \
    bash "$repo_root/scripts/bootstrap.sh" plan
)"
[[ "$complete_output" == *'pinned local tools: none'* ]]
[[ "$complete_output" == *'missing bootstrap commands: none'* ]]
[[ "$complete_output" == *'No tool downloads or host-package changes required.'* ]]

empty_output="$(
  CCVL_BOOTSTRAP_TESTING=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$empty_bin" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
  CCVL_BOOTSTRAP_TEST_MANAGER=apt \
    bash "$repo_root/scripts/bootstrap.sh" plan
)"
[[ "$empty_output" == *'pinned local tools: typst typstyle uv'* ]]
[[ "$empty_output" == *'missing bootstrap commands: downloader xz'* ]]
[[ "$empty_output" == *'host packages: curl xz-utils'* ]]
[[ "$empty_output" == *'No changes made.'* ]]

partial_output="$(
  CCVL_BOOTSTRAP_TESTING=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$partial_bin" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
  CCVL_BOOTSTRAP_TEST_MANAGER=apt \
    bash "$repo_root/scripts/bootstrap.sh" plan
)"
[[ "$partial_output" == *'pinned local tools: typst'* ]]

if CCVL_BOOTSTRAP_TEST_PLATFORM=Plan9-x86_64 bash "$repo_root/scripts/bootstrap.sh" plan >/dev/null 2>&1; then
  printf 'Unsupported platforms must fail.\n' >&2
  exit 1
fi

if CCVL_BOOTSTRAP_TESTING=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$empty_bin" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
  bash "$repo_root/scripts/bootstrap.sh" install >/dev/null 2>"$scratch/no-manager-error"; then
  printf 'Installation without a package manager must fail.\n' >&2
  exit 1
fi
grep -Fxq \
  'No supported package manager found for missing bootstrap commands: downloader xz' \
  "$scratch/no-manager-error"

mac_output="$(
  CCVL_BOOTSTRAP_TESTING=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$complete_bin" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Darwin-aarch64 \
    bash "$repo_root/scripts/bootstrap.sh" plan
)"
[[ "$mac_output" == *'platform: Darwin-aarch64'* ]]
[[ "$mac_output" == *'missing bootstrap commands: none'* ]]

printf 'POSIX bootstrap handles Linux and macOS empty, partial, complete, unsupported, and manager-less states.\n'
