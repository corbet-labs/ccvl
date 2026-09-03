#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
local_bin="$repo_root/.cache/ccvl/bin"
export PATH="$local_bin:$PATH"
export UV_PROJECT_ENVIRONMENT="$repo_root/.cache/ccvl/venv"
export UV_CACHE_DIR="$repo_root/.cache/ccvl/uv-cache"
export UV_PYTHON_INSTALL_DIR="$repo_root/.cache/ccvl/python"

# shellcheck source=scripts/tool-versions.sh
source "$repo_root/scripts/tool-versions.sh"
pypdf_version="$(awk -F'==' '/"pypdf==/ { gsub(/[", ]/, "", $2); print $2; exit }' "$repo_root/pyproject.toml")"

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap.sh [plan|install]

  plan     Report exact missing tools and intended changes. This is the default.
  install  Install pinned local tools and the locked Python runtime, then verify.
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
for tool in typst typstyle uv; do
  if ! ccvl_select_tool_asset "$tool" "$platform"; then
    printf 'Unsupported platform: %s. Use Linux or macOS on x86_64/aarch64, or native Windows.\n' "$platform" >&2
    exit 2
  fi
done

tool_matches() {
  local command_name="$1"
  local expected="$2"
  local command_path
  command_path="$(probe "$command_name")" || return 1
  "$command_path" --version 2>&1 | grep -Fq "$expected"
}

pinned_tools=()
pinned_tool_count=0
if [[ "${CCVL_BOOTSTRAP_FORCE_LOCAL:-0}" == 1 ]]; then
  if [[ ! -x "$local_bin/typst" ]] \
    || ! "$local_bin/typst" --version 2>&1 | grep -Fq "typst $CCVL_TYPST_VERSION"; then
    pinned_tools+=(typst)
    ((pinned_tool_count += 1))
  fi
  if [[ ! -x "$local_bin/typstyle" ]] \
    || ! "$local_bin/typstyle" --version 2>&1 | grep -Fq "$CCVL_TYPSTYLE_VERSION"; then
    pinned_tools+=(typstyle)
    ((pinned_tool_count += 1))
  fi
  if [[ ! -x "$local_bin/uv" ]] \
    || ! "$local_bin/uv" --version 2>&1 | grep -Fq "uv $CCVL_UV_VERSION"; then
    pinned_tools+=(uv)
    ((pinned_tool_count += 1))
  fi
else
  if ! tool_matches typst "typst $CCVL_TYPST_VERSION"; then
    pinned_tools+=(typst)
    ((pinned_tool_count += 1))
  fi
  if ! tool_matches typstyle "$CCVL_TYPSTYLE_VERSION"; then
    pinned_tools+=(typstyle)
    ((pinned_tool_count += 1))
  fi
  if ! tool_matches uv "uv $CCVL_UV_VERSION"; then
    pinned_tools+=(uv)
    ((pinned_tool_count += 1))
  fi
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
    Darwin-*) probe brew >/dev/null && manager=brew ;;
  esac
fi

missing_bootstrap=()
missing_bootstrap_count=0
if ((pinned_tool_count > 0)); then
  if ! probe curl >/dev/null && ! probe wget >/dev/null; then
    missing_bootstrap+=(downloader)
    ((missing_bootstrap_count += 1))
  fi
  if [[ "$platform" == Linux-* ]] && ! probe xz >/dev/null; then
    missing_bootstrap+=(xz)
    ((missing_bootstrap_count += 1))
  fi
fi

system_packages=()
system_package_count=0
if ((missing_bootstrap_count > 0)); then
  for command_name in "${missing_bootstrap[@]}"; do
    case "$manager:$command_name" in
      apt:downloader | dnf:downloader | pacman:downloader | brew:downloader)
        system_packages+=(curl)
        ((system_package_count += 1))
        ;;
      apt:xz)
        system_packages+=(xz-utils)
        ((system_package_count += 1))
        ;;
      dnf:xz | pacman:xz | brew:xz)
        system_packages+=(xz)
        ((system_package_count += 1))
        ;;
      nix:downloader)
        system_packages+=(nixpkgs#curl)
        ((system_package_count += 1))
        ;;
      nix:xz)
        system_packages+=(nixpkgs#xz)
        ((system_package_count += 1))
        ;;
    esac
  done
fi

pinned_tools_display=none
missing_bootstrap_display=none
system_packages_display=none
if ((pinned_tool_count > 0)); then pinned_tools_display="${pinned_tools[*]}"; fi
if ((missing_bootstrap_count > 0)); then missing_bootstrap_display="${missing_bootstrap[*]}"; fi
if ((system_package_count > 0)); then system_packages_display="${system_packages[*]}"; fi

printf 'ccvl bootstrap plan\n'
printf '  platform: %s\n' "$platform"
printf '  pinned local tools: %s\n' "$pinned_tools_display"
runtime_state='synchronize'
runtime_python="$repo_root/.cache/ccvl/venv/bin/python"
if [[ -x "$runtime_python" ]] \
  && "$runtime_python" -c \
    'import platform, pypdf, sys; sys.exit(platform.python_version() != sys.argv[1] or pypdf.__version__ != sys.argv[2])' \
    "$(<"$repo_root/.python-version")" "$pypdf_version"; then
  runtime_state='ready'
fi
printf '  managed runtime: %s (Python %s with frozen uv.lock)\n' \
  "$runtime_state" "$(<"$repo_root/.python-version")"
printf '  missing bootstrap commands: %s\n' "$missing_bootstrap_display"
printf '  package manager: %s\n' "${manager:-none}"
printf '  host packages: %s\n' "$system_packages_display"

if ((pinned_tool_count == 0 && missing_bootstrap_count == 0)); then
  printf 'No tool downloads or host-package changes required.\n'
fi
if [[ "$mode" == plan ]]; then
  printf 'No changes made. Run bash ./ccvl setup to execute this plan.\n'
  exit 0
fi
if [[ -z "$manager" ]] && ((missing_bootstrap_count > 0)); then
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

if ((system_package_count > 0)); then
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

install_tool() {
  local tool="$1"
  local archive extract_dir source_path
  ccvl_select_tool_asset "$tool" "$platform"
  archive="$bootstrap_tmp/$CCVL_TOOL_ASSET"
  fetch "$CCVL_TOOL_URL" "$archive"
  verify_sha256 "$CCVL_TOOL_SHA256" "$archive"
  if [[ "$CCVL_TOOL_KIND" == file ]]; then
    cp "$archive" "$local_bin/$tool"
  else
    extract_dir="$bootstrap_tmp/$tool"
    mkdir -p "$extract_dir"
    tar -xf "$archive" -C "$extract_dir"
    source_path="$(find "$extract_dir" -type f -name "$tool" -print -quit)"
    [[ -n "$source_path" ]] || { printf '%s was not found in its archive.\n' "$tool" >&2; return 1; }
    cp "$source_path" "$local_bin/$tool"
  fi
  chmod 0755 "$local_bin/$tool"
}

mkdir -p "$local_bin"
bootstrap_tmp="$(mktemp -d "${TMPDIR:-/tmp}/ccvl-bootstrap.XXXXXXXX")"
trap 'rm -rf -- "$bootstrap_tmp"' EXIT
if ((pinned_tool_count > 0)); then
  for tool in "${pinned_tools[@]}"; do
    install_tool "$tool"
  done
fi

uv_path="$(command -v uv)"
cd "$repo_root"
"$uv_path" sync --frozen --no-dev --python "$(<"$repo_root/.python-version")"
"$uv_path" run --frozen --no-dev --python "$(<"$repo_root/.python-version")" python "$repo_root/scripts/doctor.py"
printf 'Bootstrap complete. Managed runtime ready; downloaded assets remain below .cache/ccvl/.\n'
