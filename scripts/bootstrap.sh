#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
local_bin="$repo_root/.cache/ccvl/bin"
export PATH="$local_bin:$PATH"

# shellcheck source=scripts/tool-versions.sh
source "$repo_root/scripts/tool-versions.sh"

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap.sh [plan|install]

  plan     Report exact missing tools and intended changes. This is the default.
  install  Install missing host packages and pinned tools, then verify them.
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
if ! ccvl_select_tool_assets "$platform"; then
  printf 'Unsupported platform: %s. Use Linux x86_64/aarch64, macOS x86_64/arm64, or WSL.\n' "$platform" >&2
  exit 2
fi

required_commands=(cmp file pdfdetach pdfinfo pdfimages pdffonts pdftoppm pdftotext python3 qpdf rg)
missing_commands=()
for command_name in "${required_commands[@]}"; do
  probe "$command_name" >/dev/null || missing_commands+=("$command_name")
done

tool_matches() {
  local command_name="$1"
  local expected="$2"
  local command_path
  command_path="$(probe "$command_name")" || return 1
  "$command_path" --version 2>&1 | grep -Fq "$expected"
}

pinned_tools=()
tool_matches typst "typst $CCVL_TYPST_VERSION" || pinned_tools+=(typst)
tool_matches typstyle "$CCVL_TYPSTYLE_VERSION" || pinned_tools+=(typstyle)
tool_matches just "just $CCVL_JUST_VERSION" || pinned_tools+=(just)

manager="${CCVL_BOOTSTRAP_TEST_MANAGER:-}"
if [[ -z "$manager" ]]; then
  case "$platform" in
    Darwin-*) probe brew >/dev/null && manager=brew ;;
    Linux-*)
      if probe apt-get >/dev/null; then manager=apt
      elif probe dnf >/dev/null; then manager=dnf
      elif probe pacman >/dev/null; then manager=pacman
      elif probe nix >/dev/null; then manager=nix
      fi
      ;;
  esac
fi

add_unique() {
  local candidate="$1"
  shift
  local existing
  for existing in "$@"; do
    [[ "$existing" == "$candidate" ]] && return
  done
  system_packages+=("$candidate")
}

system_packages=()
for command_name in "${missing_commands[@]}"; do
  case "$manager:$command_name" in
    apt:cmp) add_unique diffutils "${system_packages[@]}" ;;
    apt:file) add_unique file "${system_packages[@]}" ;;
    apt:pdf*) add_unique poppler-utils "${system_packages[@]}" ;;
    apt:python3) add_unique python3 "${system_packages[@]}" ;;
    apt:qpdf) add_unique qpdf "${system_packages[@]}" ;;
    apt:rg) add_unique ripgrep "${system_packages[@]}" ;;
    dnf:cmp) add_unique diffutils "${system_packages[@]}" ;;
    dnf:file) add_unique file "${system_packages[@]}" ;;
    dnf:pdf*) add_unique poppler-utils "${system_packages[@]}" ;;
    dnf:python3) add_unique python3 "${system_packages[@]}" ;;
    dnf:qpdf) add_unique qpdf "${system_packages[@]}" ;;
    dnf:rg) add_unique ripgrep "${system_packages[@]}" ;;
    pacman:cmp) add_unique diffutils "${system_packages[@]}" ;;
    pacman:file) add_unique file "${system_packages[@]}" ;;
    pacman:pdf*) add_unique poppler "${system_packages[@]}" ;;
    pacman:python3) add_unique python "${system_packages[@]}" ;;
    pacman:qpdf) add_unique qpdf "${system_packages[@]}" ;;
    pacman:rg) add_unique ripgrep "${system_packages[@]}" ;;
    brew:cmp | brew:file) ;;
    brew:pdf*) add_unique poppler "${system_packages[@]}" ;;
    brew:python3) add_unique python "${system_packages[@]}" ;;
    brew:qpdf) add_unique qpdf "${system_packages[@]}" ;;
    brew:rg) add_unique ripgrep "${system_packages[@]}" ;;
    nix:cmp) add_unique nixpkgs#diffutils "${system_packages[@]}" ;;
    nix:file) add_unique nixpkgs#file "${system_packages[@]}" ;;
    nix:pdf*) add_unique nixpkgs#poppler_utils "${system_packages[@]}" ;;
    nix:python3) add_unique nixpkgs#python3 "${system_packages[@]}" ;;
    nix:qpdf) add_unique nixpkgs#qpdf "${system_packages[@]}" ;;
    nix:rg) add_unique nixpkgs#ripgrep "${system_packages[@]}" ;;
  esac
done

if ((${#pinned_tools[@]} > 0)); then
  if ! probe curl >/dev/null && ! probe wget >/dev/null; then
    case "$manager" in
      apt | dnf | pacman) add_unique curl "${system_packages[@]}" ;;
      brew) add_unique curl "${system_packages[@]}" ;;
      nix) add_unique nixpkgs#curl "${system_packages[@]}" ;;
    esac
  fi
  if ! probe xz >/dev/null; then
    case "$manager" in
      apt) add_unique xz-utils "${system_packages[@]}" ;;
      dnf | pacman | brew) add_unique xz "${system_packages[@]}" ;;
      nix) add_unique nixpkgs#xz "${system_packages[@]}" ;;
    esac
  fi
fi

printf 'ccvl bootstrap plan\n'
printf '  platform: %s\n' "$platform"
printf '  missing host commands: %s\n' "${missing_commands[*]:-none}"
printf '  pinned local tools: %s\n' "${pinned_tools[*]:-none}"
printf '  package manager: %s\n' "${manager:-none}"
printf '  host packages: %s\n' "${system_packages[*]:-none}"

if ((${#missing_commands[@]} == 0 && ${#pinned_tools[@]} == 0)); then
  printf 'No changes required. The complete toolchain is already available.\n'
  exit 0
fi
if [[ "$mode" == plan ]]; then
  printf 'No changes made. Run bash ./ccvl setup to execute this plan.\n'
  exit 0
fi
if [[ -z "$manager" && ${#missing_commands[@]} -gt 0 ]]; then
  printf 'No supported package manager found for missing host tools.\n' >&2
  exit 2
fi
if [[ -z "$manager" && ${#pinned_tools[@]} -gt 0 ]] \
  && ! probe curl >/dev/null && ! probe wget >/dev/null; then
  printf 'No supported package manager, curl, or wget found for pinned tool downloads.\n' >&2
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

if ((${#system_packages[@]} > 0)); then
  case "$manager" in
    apt)
      as_root apt-get update
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install --yes "${system_packages[@]}"
      ;;
    dnf) as_root dnf install --assumeyes "${system_packages[@]}" ;;
    pacman) as_root pacman -S --needed --noconfirm "${system_packages[@]}" ;;
    brew) brew install "${system_packages[@]}" ;;
    nix) nix profile install "${system_packages[@]}" ;;
  esac
fi

fetch() {
  local url="$1"
  local output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --proto '=https' --tlsv1.2 "$url" --output "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget --https-only --output-document="$output" "$url"
  else
    printf 'curl or wget is required to download pinned tools.\n' >&2
    return 1
  fi
}

verify_sha256() {
  local expected="$1"
  local path="$2"
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$path" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$path" | awk '{print $1}')"
  else
    printf 'A SHA-256 verifier is required before installing downloaded tools.\n' >&2
    return 1
  fi
  [[ "$actual" == "$expected" ]] || {
    printf 'Checksum mismatch for %s\n' "$path" >&2
    return 1
  }
}

install_archive_tool() {
  local name="$1"
  local url="$2"
  local expected="$3"
  local archive="$bootstrap_tmp/$name.archive"
  local extract_dir="$bootstrap_tmp/$name"
  fetch "$url" "$archive"
  verify_sha256 "$expected" "$archive"
  mkdir -p "$extract_dir"
  tar -xf "$archive" -C "$extract_dir"
  source_path="$(find "$extract_dir" -type f -name "$name" -print -quit)"
  [[ -n "$source_path" ]] || { printf '%s was not found in its archive.\n' "$name" >&2; return 1; }
  cp "$source_path" "$local_bin/$name"
  chmod 0755 "$local_bin/$name"
}

mkdir -p "$local_bin"
bootstrap_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ccvl-bootstrap.XXXXXXXX")"
trap 'rm -rf -- "$bootstrap_tmp"' EXIT
for tool in "${pinned_tools[@]}"; do
  case "$tool" in
    typst) install_archive_tool typst "$CCVL_TYPST_URL" "$CCVL_TYPST_SHA256" ;;
    just) install_archive_tool just "$CCVL_JUST_URL" "$CCVL_JUST_SHA256" ;;
    typstyle)
      fetch "$CCVL_TYPSTYLE_URL" "$bootstrap_tmp/typstyle"
      verify_sha256 "$CCVL_TYPSTYLE_SHA256" "$bootstrap_tmp/typstyle"
      cp "$bootstrap_tmp/typstyle" "$local_bin/typstyle"
      chmod 0755 "$local_bin/typstyle"
      ;;
  esac
done

bash "$repo_root/scripts/doctor.sh"
printf 'Bootstrap complete. Pinned tools are isolated in .cache/ccvl/bin.\n'
