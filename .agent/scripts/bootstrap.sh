#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cache_root="${CCVL_BOOTSTRAP_CACHE_ROOT:-$repo_root/.agent/cache/ccvl}"
local_bin="$cache_root/bin"
cargo_home="$cache_root/cargo"
rustup_home="$cache_root/rustup"
target_dir="$cache_root/target"
binary="$local_bin/ccvl"
install_stamp="$cache_root/install.sha256"
prebuilt_stamp="$cache_root/install-prebuilt.sha256"
release_base="${CCVL_RELEASE_BASE:-https://github.com/corbet-labs/ccvl/releases/download/continuous}"
rust_version="$(sed -n 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$repo_root/rust-toolchain.toml")"

# shellcheck source=.agent/scripts/tool-versions.sh
source "$repo_root/.agent/scripts/tool-versions.sh"

usage() {
  cat <<'EOF'
Usage: .agent/scripts/bootstrap.sh [plan|install]

  plan     Report the exact build plan without changing anything. This is the default.
  install  Prepare exact Rust locally when needed, build ccvl, and verify it.
EOF
}

mode="${1:-plan}"
case "$mode" in
  plan | install) ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

[[ -n "$rust_version" ]] || {
  printf 'rust-toolchain.toml does not declare a Rust channel.\n' >&2
  exit 2
}

probe() {
  if [[ "${CCVL_BOOTSTRAP_TESTING:-0}" == 1 && -n "${CCVL_BOOTSTRAP_PROBE_PATH+x}" ]]; then
    PATH="$CCVL_BOOTSTRAP_PROBE_PATH" command -v "$1" 2>/dev/null
  else
    command -v "$1" 2>/dev/null
  fi
}

platform="${CCVL_BOOTSTRAP_TEST_PLATFORM:-$(uname -s)-$(uname -m)}"
platform="${platform/arm64/aarch64}"
platform="${platform/amd64/x86_64}"
if ! ccvl_select_rustup_asset "$platform"; then
  printf 'Unsupported platform: %s. Use Linux or macOS on x86_64/aarch64, or native Windows.\n' \
    "$platform" >&2
  exit 2
fi

release_asset=""
case "$platform" in
  Linux-x86_64) release_asset=ccvl-linux-x86_64 ;;
  Linux-aarch64) release_asset=ccvl-linux-aarch64 ;;
  Darwin-aarch64) release_asset=ccvl-macos-arm64 ;;
  Darwin-x86_64) release_asset=ccvl-macos-x86_64 ;;
esac

version_matches() {
  local output="$1"
  [[ "$output" == "rustc $rust_version" || "$output" == "rustc $rust_version "* ]]
}

find_brew() {
  local found
  found="$(probe brew)" && {
    printf '%s\n' "$found"
    return 0
  }
  if [[ "${CCVL_BOOTSTRAP_TESTING:-0}" == 1 ]]; then
    return 1
  fi
  case "$platform" in
    Darwin-aarch64) found=/opt/homebrew/bin/brew ;;
    Darwin-x86_64) found=/usr/local/bin/brew ;;
    *) return 1 ;;
  esac
  [[ -x "$found" ]] || return 1
  printf '%s\n' "$found"
}

brew_rustup() {
  local brew prefix
  brew="$(find_brew)" || return 1
  prefix="$("$brew" --prefix rustup 2>/dev/null)" || return 1
  [[ -x "$prefix/bin/rustup" ]] || return 1
  printf '%s\n' "$prefix/bin/rustup"
}

managed_rust_matches() {
  local rustup output
  if [[ "$platform" == Darwin-* ]]; then
    rustup="$(brew_rustup)" || return 1
  else
    rustup="$cargo_home/bin/rustup"
    [[ -x "$rustup" ]] || return 1
  fi
  output="$({
    cd "${TMPDIR:-/tmp}"
    CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" \
      "$rustup" run "$rust_version" rustc --version
  } 2>/dev/null)" || return 1
  version_matches "$output" || return 1
  {
    cd "${TMPDIR:-/tmp}"
    CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" \
      "$rustup" run "$rust_version" cargo --version >/dev/null 2>&1
  }
}

system_kind=none
system_cargo=
system_rustup=
if [[ "${CCVL_BOOTSTRAP_FORCE_LOCAL:-0}" != 1 ]]; then
  candidate_rustup="$(probe rustup)" || candidate_rustup=
  if [[ -n "$candidate_rustup" ]]; then
    candidate_output="$({
      cd "${TMPDIR:-/tmp}"
      "$candidate_rustup" run "$rust_version" rustc --version
    } 2>/dev/null)" || candidate_output=
    if version_matches "$candidate_output" && {
      cd "${TMPDIR:-/tmp}"
      "$candidate_rustup" run "$rust_version" cargo --version >/dev/null 2>&1
    }; then
      system_kind=rustup
      system_rustup="$candidate_rustup"
    fi
  fi
  if [[ "$system_kind" == none && -z "$candidate_rustup" ]]; then
    candidate_rustc="$(probe rustc)" || candidate_rustc=
    candidate_cargo="$(probe cargo)" || candidate_cargo=
    if [[ -n "$candidate_rustc" && -n "$candidate_cargo" ]]; then
      candidate_output="$({
        unset RUSTUP_TOOLCHAIN
        cd "${TMPDIR:-/tmp}"
        "$candidate_rustc" --version
      } 2>/dev/null)" || candidate_output=
      if version_matches "$candidate_output"; then
        system_kind=standalone
        system_cargo="$candidate_cargo"
      fi
    fi
  fi
fi

hash_stream() {
  if probe sha256sum >/dev/null; then
    sha256sum | awk '{ print $1 }'
  elif probe shasum >/dev/null; then
    shasum -a 256 | awk '{ print $1 }'
  else
    return 1
  fi
}

hash_file() {
  local path="$1"
  if probe sha256sum >/dev/null; then
    sha256sum "$path" | awk '{ print $1 }'
  elif probe shasum >/dev/null; then
    shasum -a 256 "$path" | awk '{ print $1 }'
  else
    return 1
  fi
}

source_fingerprint() {
  if [[ "${CCVL_BOOTSTRAP_TESTING:-0}" == 1 ]]; then
    printf '%s\n' "${CCVL_BOOTSTRAP_TEST_FINGERPRINT:-test-fingerprint}"
    return 0
  fi
  {
    for relative in Cargo.toml Cargo.lock rust-toolchain.toml; do
      printf '%s %s\n' "$relative" "$(hash_file "$repo_root/$relative")"
    done
    find "$repo_root/.agent/src" -type f -name '*.rs' -print | LC_ALL=C sort | while IFS= read -r path; do
      relative="${path#"$repo_root/"}"
      printf '%s %s\n' "$relative" "$(hash_file "$path")"
    done
  } | hash_stream
}

binary_state=install
fingerprint="$(source_fingerprint 2>/dev/null)" || fingerprint=
if [[ -x "$binary" && -n "$fingerprint" ]]; then
  if [[ -f "$install_stamp" ]] && [[ "$(<"$install_stamp")" == "$fingerprint" ]]; then
    binary_state=ready
  elif [[ -f "$prebuilt_stamp" ]]; then
    prebuilt_record="$(<"$prebuilt_stamp")"
    prebuilt_bin="${prebuilt_record%% *}"
    prebuilt_fp="${prebuilt_record#* }"
    if [[ -n "$prebuilt_bin" && -n "$prebuilt_fp" && "$prebuilt_fp" == "$fingerprint" ]] \
      && [[ "$(hash_file "$binary" 2>/dev/null)" == "$prebuilt_bin" ]]; then
      binary_state=ready
    fi
  fi
fi

toolchain_state=install
if managed_rust_matches; then
  toolchain_state=managed
elif [[ "$system_kind" != none ]]; then
  toolchain_state=system
fi

# A prebuilt binary needs no toolchain and no compiler: it downloads in
# seconds while a source build takes minutes. Fetch is the primary path
# whenever the platform asset is known and a downloader plus checksum
# verifier exist; the source build remains the offline fallback.
fetch_enabled=0
if [[ -n "$release_asset" && "${CCVL_BOOTSTRAP_FORCE_LOCAL:-0}" != 1 ]] \
  && { probe curl >/dev/null || probe wget >/dev/null; } \
  && { probe sha256sum >/dev/null || probe shasum >/dev/null; }; then
  fetch_enabled=1
fi

manager="${CCVL_BOOTSTRAP_TEST_MANAGER:-}"
if [[ -z "$manager" ]]; then
  case "$platform" in
    Linux-*)
      if probe apt-get >/dev/null; then manager=apt
      elif probe dnf >/dev/null; then manager=dnf
      elif probe pacman >/dev/null; then manager=pacman
      elif probe nix >/dev/null; then manager=nix
      fi
      ;;
    Darwin-*) manager=brew ;;
  esac
fi

missing_bootstrap=()
host_packages=()
append_unique() {
  local candidate="$1"
  local existing
  for existing in "${host_packages[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  host_packages+=("$candidate")
}

if [[ "$binary_state" == install || "$toolchain_state" == install ]]; then
  if ! probe sha256sum >/dev/null && ! probe shasum >/dev/null; then
    missing_bootstrap+=(checksum)
  fi
fi
if [[ "$binary_state" == install && "$fetch_enabled" == 0 ]]; then
  if ! probe cc >/dev/null && [[ "$platform" != Darwin-* ]]; then
    missing_bootstrap+=(compiler)
  fi
fi

if [[ "$platform" == Linux-* && "$toolchain_state" == install ]] \
  && ! probe curl >/dev/null && ! probe wget >/dev/null; then
  missing_bootstrap+=(downloader)
fi
if [[ "$toolchain_state" == install ]]; then
  case "$platform" in
    Darwin-*)
      if ! find_brew >/dev/null; then
        missing_bootstrap+=(homebrew)
        append_unique Homebrew
      fi
      if ! brew_rustup >/dev/null; then
        missing_bootstrap+=(rustup)
        append_unique rustup
      fi
      ;;
  esac
fi

if [[ "$platform" == Linux-* ]]; then
  for requirement in "${missing_bootstrap[@]}"; do
    case "$manager:$requirement" in
      apt:downloader | dnf:downloader | pacman:downloader) append_unique curl ;;
      nix:downloader) append_unique nixpkgs#curl ;;
      apt:checksum | dnf:checksum | pacman:checksum) append_unique coreutils ;;
      nix:checksum) append_unique nixpkgs#coreutils ;;
      apt:compiler) append_unique build-essential ;;
      dnf:compiler) append_unique gcc ;;
      pacman:compiler) append_unique base-devel ;;
      nix:compiler) append_unique nixpkgs#gcc ;;
    esac
  done
fi

missing_display=none
host_packages_display=none
if ((${#missing_bootstrap[@]} > 0)); then missing_display="${missing_bootstrap[*]}"; fi
if ((${#host_packages[@]} > 0)); then host_packages_display="${host_packages[*]}"; fi

printf 'ccvl bootstrap plan\n'
printf '  platform: %s\n' "$platform"
case "$toolchain_state" in
  managed) printf '  Rust toolchain: managed %s\n' "$rust_version" ;;
  system) printf '  Rust toolchain: system %s\n' "$rust_version" ;;
  install)
    if [[ "$platform" == Darwin-* ]]; then
      printf '  Rust toolchain: install %s with Homebrew rustup\n' "$rust_version"
    else
      printf '  Rust toolchain: install %s with pinned rustup-init %s\n' \
        "$rust_version" "$CCVL_RUSTUP_VERSION"
    fi
    ;;
esac
printf '  ccvl binary: %s\n' "$binary_state"
if [[ "$binary_state" == install && "$fetch_enabled" == 1 ]]; then
  printf '  prebuilt binary: %s (source build on fetch failure)\n' "$release_asset"
fi
printf '  missing bootstrap commands: %s\n' "$missing_display"
printf '  package manager: %s\n' "${manager:-none}"
printf '  host packages: %s\n' "$host_packages_display"
if [[ "$toolchain_state" == install && "$platform" == Darwin-* ]]; then
  if ! find_brew >/dev/null; then
    # The literal command is shown for an exact, auditable plan; setup downloads it to a file.
    # shellcheck disable=SC2016
    printf '%s\n' \
      '  Homebrew install action: NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    printf '  shell startup files: no ccvl edits; brew is resolved from its platform prefix\n'
  fi
  if ! brew_rustup >/dev/null; then
    printf '  Homebrew package action: brew install rustup\n'
  fi
fi

if [[ "$binary_state" == ready ]]; then
  printf 'No ccvl build changes required.\n'
fi
if [[ "$mode" == plan ]]; then
  printf 'No changes made. Run bash ./ccvl setup to execute this plan.\n'
  exit 0
fi

if [[ "$platform" == Linux-* && ${#missing_bootstrap[@]} -gt 0 && -z "$manager" ]]; then
  printf 'No supported package manager found for missing bootstrap commands: %s\n' \
    "${missing_bootstrap[*]}" >&2
  exit 2
fi

as_root() {
  if ((EUID == 0)); then
    "$@"
  elif probe sudo >/dev/null; then
    sudo "$@"
  else
    printf 'Installing host packages requires root or sudo: %s\n' "$*" >&2
    return 1
  fi
}

if [[ "$platform" == Linux-* && ${#host_packages[@]} -gt 0 ]]; then
  case "$manager" in
    apt)
      as_root apt-get update
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install --yes "${host_packages[@]}"
      ;;
    dnf) as_root dnf install --assumeyes "${host_packages[@]}" ;;
    pacman) as_root pacman -S --needed --noconfirm "${host_packages[@]}" ;;
    nix) nix profile install "${host_packages[@]}" ;;
  esac
fi

bootstrap_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ccvl-bootstrap.XXXXXXXX")"
trap 'rm -rf -- "$bootstrap_tmp"' EXIT

fetch() {
  local url="$1"
  local output="$2"
  local downloader=
  if downloader="$(probe curl 2>/dev/null)" && [[ -n "$downloader" ]]; then
    "$downloader" --fail --location --proto '=https' --tlsv1.2 "$url" --output "$output"
  elif downloader="$(probe wget 2>/dev/null)" && [[ -n "$downloader" ]]; then
    "$downloader" --https-only --output-document="$output" "$url"
  else
    printf 'curl or wget is required to download a bootstrap asset.\n' >&2
    return 1
  fi
}

verify_sha256() {
  local expected="$1"
  local path="$2"
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$path" | awk '{ print $1 }')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$path" | awk '{ print $1 }')"
  else
    printf 'A SHA-256 verifier is required before installing a downloaded asset.\n' >&2
    return 1
  fi
  [[ "$actual" == "$expected" ]] || {
    printf 'Checksum mismatch for %s\n' "$path" >&2
    return 1
  }
}

fetch_prebuilt() {
  local staged="$bootstrap_tmp/$release_asset"
  local staged_checksum="$staged.sha256"
  local expected bin_sha current
  fetch "$release_base/$release_asset" "$staged" || return 1
  fetch "$release_base/$release_asset.sha256" "$staged_checksum" || return 1
  expected="$(awk '{ print $1 }' "$staged_checksum")" || return 1
  [[ -n "$expected" ]] || return 1
  verify_sha256 "$expected" "$staged" || return 1
  chmod 0755 "$staged" || return 1
  mkdir -p "$local_bin" || return 1
  cp "$staged" "$binary" || return 1
  bin_sha="$(hash_file "$binary")" || return 1
  current="$(source_fingerprint)" || return 1
  printf '%s %s\n' "$bin_sha" "$current" > "$prebuilt_stamp" || return 1
}

fetched_binary=0
if [[ "$binary_state" == install && -n "$release_asset" && "${CCVL_BOOTSTRAP_FORCE_LOCAL:-0}" != 1 ]] \
  && { probe curl >/dev/null || probe wget >/dev/null; } \
  && { probe sha256sum >/dev/null || probe shasum >/dev/null; }; then
  if fetch_prebuilt; then
    fetched_binary=1
  else
    printf 'Prebuilt binary unavailable; falling back to a source build.\n' >&2
    if ! probe cc >/dev/null && [[ "$platform" != Darwin-* ]]; then
      printf 'Source-build fallback needs a C compiler (cc).\n' >&2
      printf 'Install a compiler or provide network access to %s.\n' "$release_base" >&2
      exit 2
    fi
  fi
fi

if [[ "$toolchain_state" == install && "$fetched_binary" == 0 ]]; then
  mkdir -p "$cargo_home" "$rustup_home"
  if [[ "$platform" == Darwin-* ]]; then
    brew="$(find_brew)" || brew=
    if [[ -z "$brew" ]]; then
      homebrew_installer="$bootstrap_tmp/install-homebrew.sh"
      fetch \
        https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
        "$homebrew_installer"
      NONINTERACTIVE=1 /bin/bash "$homebrew_installer"
      brew="$(find_brew)" || {
        printf 'Homebrew installation completed but brew was not found in its platform prefix.\n' >&2
        exit 2
      }
    fi
    if ! brew_rustup >/dev/null; then
      "$brew" install rustup
    fi
    rustup="$(brew_rustup)" || {
      printf 'Homebrew rustup was not found after installation.\n' >&2
      exit 2
    }
    CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" \
      "$rustup" toolchain install "$rust_version" --profile minimal
  else
    rustup_init="$bootstrap_tmp/$CCVL_RUSTUP_ASSET"
    fetch "$CCVL_RUSTUP_URL" "$rustup_init"
    verify_sha256 "$CCVL_RUSTUP_SHA256" "$rustup_init"
    chmod 0755 "$rustup_init"
    CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" \
      "$rustup_init" -y --no-modify-path --profile minimal --default-toolchain "$rust_version"
  fi
  managed_rust_matches || {
    printf 'Managed Rust %s is unavailable after installation.\n' "$rust_version" >&2
    exit 2
  }
  toolchain_state=managed
fi

if [[ "$binary_state" == install && "$fetched_binary" == 0 ]]; then
  mkdir -p "$cache_root" "$cargo_home" "$target_dir"
  cargo_args=(install --locked --force --path "$repo_root" --root "$cache_root")
  case "$toolchain_state" in
    managed)
      if [[ "$platform" == Darwin-* ]]; then
        rustup="$(brew_rustup)"
      else
        rustup="$cargo_home/bin/rustup"
      fi
      (
        cd "$bootstrap_tmp"
        CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" CARGO_TARGET_DIR="$target_dir" \
          "$rustup" run "$rust_version" cargo "${cargo_args[@]}"
      )
      ;;
    system)
      if [[ "$system_kind" == rustup ]]; then
        (
          cd "$bootstrap_tmp"
          CARGO_HOME="$cargo_home" CARGO_TARGET_DIR="$target_dir" \
            "$system_rustup" run "$rust_version" cargo "${cargo_args[@]}"
        )
      else
        (
          unset RUSTUP_TOOLCHAIN
          cd "$bootstrap_tmp"
          CARGO_HOME="$cargo_home" CARGO_TARGET_DIR="$target_dir" \
            "$system_cargo" "${cargo_args[@]}"
        )
      fi
      ;;
  esac
  [[ -x "$binary" ]] || {
    printf 'cargo install did not produce %s\n' "$binary" >&2
    exit 2
  }
  fingerprint="$(source_fingerprint)"
  printf '%s\n' "$fingerprint" > "$install_stamp"
fi

cd "$repo_root"
"$binary" setup
printf 'Setup complete. The repository-local binary is %s.\n' "$binary"
