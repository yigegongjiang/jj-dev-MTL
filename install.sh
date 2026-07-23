#!/usr/bin/env bash
# Install the latest jj-dev-MTL.app from GitHub Releases into /Applications.
# Usage: curl -fsSL https://raw.githubusercontent.com/yigegongjiang/jj-dev-MTL/main/install.sh | bash

set -euo pipefail

REPO="yigegongjiang/jj-dev-MTL"
APP_NAME="jj-dev-MTL"
ASSET="${APP_NAME}-macos.zip"
INSTALL_DIR="/Applications"

err() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '==> %s\n' "$*"; }

command -v curl >/dev/null 2>&1 || err "curl is required"
command -v unzip >/dev/null 2>&1 || err "unzip is required"
command -v shasum >/dev/null 2>&1 || err "shasum is required"

[ "$(uname -s)" = "Darwin" ] || err "unsupported OS: $(uname -s) (macOS only)"

base="https://github.com/${REPO}/releases/latest/download"
tmpdir="$(mktemp -d -t jj-dev-MTL-install)"
trap 'rm -rf "$tmpdir"' EXIT

log "downloading ${ASSET}"
curl -fL --progress-bar --retry 3 -o "${tmpdir}/${ASSET}" "${base}/${ASSET}" \
  || err "download failed: ${base}/${ASSET}"

# Optional checksum verification (skip silently if release has no checksums.txt).
if hash_line="$(curl -fsSL --retry 3 "${base}/checksums.txt" 2>/dev/null | grep -F "  ${ASSET}" || true)"; then
  if [ -n "$hash_line" ]; then
    expected="${hash_line%% *}"
    actual="$(shasum -a 256 "${tmpdir}/${ASSET}" | awk '{print $1}')"
    [ "$expected" = "$actual" ] || err "checksum mismatch (expected ${expected}, got ${actual})"
    log "checksum verified"
  fi
fi

log "extracting"
unzip -q "${tmpdir}/${ASSET}" -d "${tmpdir}/unpacked"
app_path="$(find "${tmpdir}/unpacked" -maxdepth 2 -name '*.app' -print -quit)"
[ -n "$app_path" ] || err "no .app bundle inside ${ASSET}"

target="${INSTALL_DIR}/$(basename "$app_path")"

log "installing to ${target}"
if [ -e "$target" ]; then
  if [ -w "$INSTALL_DIR" ]; then rm -rf "$target"; else sudo rm -rf "$target"; fi
fi
if [ -w "$INSTALL_DIR" ]; then
  mv "$app_path" "$target"
else
  sudo mv "$app_path" "$target"
fi

# Ad-hoc signed apps still get quarantined on download; strip so Gatekeeper won't block first launch.
if [ -w "$target" ]; then
  xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
else
  sudo xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
fi

log "installed: ${target}"
log "open with: open \"${target}\""
