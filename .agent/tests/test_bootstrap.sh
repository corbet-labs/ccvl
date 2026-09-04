#!/usr/bin/env bash
set -euo pipefail

# Keep the simulated probe matrix independent from the caller's environment.
export CCVL_BOOTSTRAP_FORCE_LOCAL=0
export CCVL_BOOTSTRAP_TESTING=1
export CCVL_BOOTSTRAP_TEST_FINGERPRINT=test-fingerprint

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/ccvl-bootstrap-test.XXXXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

create_fake() {
  local directory="$1"
  local name="$2"
  local output="${3:-}"
  mkdir -p "$directory"
  printf '#!/bin/sh\nprintf "%%s\\n" %q\n' "$output" > "$directory/$name"
  chmod 0755 "$directory/$name"
}

create_exact_rustup() {
  local directory="$1"
  mkdir -p "$directory"
  printf '%s\n' \
    '#!/bin/sh' \
    'case "$*" in' \
    '  "run 1.94.0 rustc --version") printf "%s\n" "rustc 1.94.0 (test)" ;;' \
    '  "run 1.94.0 cargo --version") printf "%s\n" "cargo 1.94.0 (test)" ;;' \
    '  *) exit 1 ;;' \
    'esac' > "$directory/rustup"
  chmod 0755 "$directory/rustup"
}

mark_binary_ready() {
  local cache_root="$1"
  create_fake "$cache_root/bin" ccvl 'ccvl 0.1.0'
  printf 'test-fingerprint\n' > "$cache_root/install.sha256"
}

complete_bin="$scratch/complete-bin"
empty_bin="$scratch/empty-bin"
partial_bin="$scratch/partial-bin"
mkdir -p "$complete_bin" "$empty_bin" "$partial_bin"

for command_name in curl sha256sum cc; do
  create_fake "$complete_bin" "$command_name"
  create_fake "$partial_bin" "$command_name"
done
create_fake "$complete_bin" rustc 'rustc 1.94.0 (test)'
create_fake "$complete_bin" cargo 'cargo 1.94.0 (test)'

complete_cache="$scratch/complete-cache"
mark_binary_ready "$complete_cache"
complete_output="$(
  CCVL_BOOTSTRAP_PROBE_PATH="$complete_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$complete_cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
  CCVL_BOOTSTRAP_TEST_MANAGER=apt \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$complete_output" == *'Rust toolchain: system 1.94.0'* ]]
[[ "$complete_output" == *'ccvl binary: ready'* ]]
[[ "$complete_output" == *'missing bootstrap commands: none'* ]]
[[ "$complete_output" == *'No ccvl build changes required.'* ]]

empty_cache="$scratch/empty-cache"
empty_output="$(
  CCVL_BOOTSTRAP_PROBE_PATH="$empty_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$empty_cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
  CCVL_BOOTSTRAP_TEST_MANAGER=apt \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$empty_output" == *'Rust toolchain: install 1.94.0 with pinned rustup-init 1.29.1'* ]]
[[ "$empty_output" == *'ccvl binary: install'* ]]
[[ "$empty_output" == *'missing bootstrap commands: checksum compiler downloader'* ]]
[[ "$empty_output" == *'host packages: coreutils build-essential curl'* ]]
[[ "$empty_output" == *'No changes made.'* ]]
[[ ! -e "$empty_cache" ]]

ready_without_toolchain_cache="$scratch/ready-without-toolchain-cache"
mark_binary_ready "$ready_without_toolchain_cache"
ready_without_toolchain_output="$(
  CCVL_BOOTSTRAP_PROBE_PATH="$empty_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$ready_without_toolchain_cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
  CCVL_BOOTSTRAP_TEST_MANAGER=apt \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$ready_without_toolchain_output" == *'ccvl binary: ready'* ]]
[[ "$ready_without_toolchain_output" == *'missing bootstrap commands: checksum downloader'* ]]
[[ "$ready_without_toolchain_output" == *'host packages: coreutils curl'* ]]

partial_cache="$scratch/partial-cache"
partial_output="$(
  CCVL_BOOTSTRAP_PROBE_PATH="$partial_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$partial_cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-aarch64 \
  CCVL_BOOTSTRAP_TEST_MANAGER=apt \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$partial_output" == *'platform: Linux-aarch64'* ]]
[[ "$partial_output" == *'Rust toolchain: install 1.94.0 with pinned rustup-init 1.29.1'* ]]
[[ "$partial_output" == *'ccvl binary: install'* ]]
[[ "$partial_output" == *'missing bootstrap commands: none'* ]]

managed_cache="$scratch/managed-cache"
create_fake "$managed_cache/cargo/bin" rustup 'rustc 1.94.0 (test)'
mark_binary_ready "$managed_cache"
managed_output="$(
  CCVL_BOOTSTRAP_FORCE_LOCAL=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$partial_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$managed_cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$managed_output" == *'Rust toolchain: managed 1.94.0'* ]]
[[ "$managed_output" == *'ccvl binary: ready'* ]]

mv "$managed_cache/bin/ccvl" "$scratch/ccvl-away"
managed_partial_output="$(
  CCVL_BOOTSTRAP_FORCE_LOCAL=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$partial_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$managed_cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$managed_partial_output" == *'Rust toolchain: managed 1.94.0'* ]]
[[ "$managed_partial_output" == *'ccvl binary: install'* ]]

system_rustup_bin="$scratch/system-rustup-bin"
for command_name in curl sha256sum cc; do
  create_fake "$system_rustup_bin" "$command_name"
done
create_exact_rustup "$system_rustup_bin"
system_rustup_cache="$scratch/system-rustup-cache"
mark_binary_ready "$system_rustup_cache"
system_rustup_output="$(
  CCVL_BOOTSTRAP_FORCE_LOCAL=0 \
  CCVL_BOOTSTRAP_PROBE_PATH="$system_rustup_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$system_rustup_cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$system_rustup_output" == *'Rust toolchain: system 1.94.0'* ]]
[[ "$system_rustup_output" == *'ccvl binary: ready'* ]]

mac_empty_bin="$scratch/mac-empty-bin"
mkdir -p "$mac_empty_bin"
create_fake "$mac_empty_bin" shasum
mac_empty_output="$(
  CCVL_BOOTSTRAP_FORCE_LOCAL=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$mac_empty_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$scratch/mac-empty-cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Darwin-aarch64 \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$mac_empty_output" == *'Rust toolchain: install 1.94.0 with Homebrew rustup'* ]]
[[ "$mac_empty_output" == *'missing bootstrap commands: homebrew rustup'* ]]
[[ "$mac_empty_output" == *'host packages: Homebrew rustup'* ]]
[[ "$mac_empty_output" == *'Homebrew install action:'* ]]
[[ "$mac_empty_output" == *'Homebrew package action: brew install rustup'* ]]

mac_partial_bin="$scratch/mac-partial-bin"
mac_prefix="$scratch/homebrew/opt/rustup"
mkdir -p "$mac_partial_bin"
create_fake "$mac_partial_bin" shasum
create_fake "$mac_partial_bin" brew "$mac_prefix"
mac_partial_output="$(
  CCVL_BOOTSTRAP_FORCE_LOCAL=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$mac_partial_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$scratch/mac-partial-cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Darwin-x86_64 \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$mac_partial_output" == *'missing bootstrap commands: rustup'* ]]
[[ "$mac_partial_output" == *'host packages: rustup'* ]]
[[ "$mac_partial_output" != *'Homebrew install action:'* ]]

create_fake "$mac_prefix/bin" rustup 'rustc 1.94.0 (test)'
mac_complete_cache="$scratch/mac-complete-cache"
mark_binary_ready "$mac_complete_cache"
mac_complete_output="$(
  CCVL_BOOTSTRAP_FORCE_LOCAL=1 \
  CCVL_BOOTSTRAP_PROBE_PATH="$mac_partial_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$mac_complete_cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Darwin-x86_64 \
    bash "$repo_root/.agent/scripts/bootstrap.sh" plan
)"
[[ "$mac_complete_output" == *'Rust toolchain: managed 1.94.0'* ]]
[[ "$mac_complete_output" == *'ccvl binary: ready'* ]]
[[ "$mac_complete_output" == *'host packages: none'* ]]

if CCVL_BOOTSTRAP_TEST_PLATFORM=Plan9-x86_64 \
  bash "$repo_root/.agent/scripts/bootstrap.sh" plan >/dev/null 2>&1; then
  printf 'Unsupported platforms must fail.\n' >&2
  exit 1
fi

if CCVL_BOOTSTRAP_PROBE_PATH="$empty_bin" \
  CCVL_BOOTSTRAP_CACHE_ROOT="$scratch/managerless-cache" \
  CCVL_BOOTSTRAP_TEST_PLATFORM=Linux-x86_64 \
  bash "$repo_root/.agent/scripts/bootstrap.sh" install >/dev/null 2>"$scratch/no-manager-error"; then
  printf 'Installation without a package manager must fail.\n' >&2
  exit 1
fi
grep -Fxq \
  'No supported package manager found for missing bootstrap commands: checksum compiler downloader' \
  "$scratch/no-manager-error"

printf 'POSIX bootstrap handles Linux and macOS empty, partial, complete, unsupported, and manager-less states.\n'
