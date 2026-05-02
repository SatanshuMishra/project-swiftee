#!/usr/bin/env bash
# Compose latest.json from the macOS/windows bundles + their .sig files.
# Inputs (env): GITHUB_REF, GITHUB_REPOSITORY.
# Inputs (files): artifacts/macos/*.app.tar.gz + .sig, artifacts/windows/*-setup.exe + .sig, CHANGELOG.md.
# Output: latest.json in CWD.
set -euo pipefail
shopt -s nullglob   # missing globs expand to empty array, not literal pattern

VERSION="${GITHUB_REF#refs/tags/v}"
REPO="${GITHUB_REPOSITORY}"
PUB_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Extract release notes from the section under "## [VERSION]" until the
# next "## [" heading (or EOF). Strips the heading itself and trims trailing
# blank lines.
NOTES="$(awk -v ver="## [$VERSION]" '
  index($0, ver) == 1 { capture=1; next }
  capture && /^## \[/ { exit }
  capture { print }
' CHANGELOG.md | sed -e :a -e '/^\s*$/{$d;N;ba' -e '}')"

# Assert exactly one bundle per architecture. Multiple bundles would mean a
# stale-artifact bleed or a misconfigured bundler — fail loudly rather than
# silently picking the wrong one.
require_exactly_one() {
  local label="$1"; shift
  local -a matches=("$@")
  if [ "${#matches[@]}" -ne 1 ] || [ ! -e "${matches[0]}" ]; then
    echo "::error::Expected exactly 1 ${label}, found ${#matches[@]}: ${matches[*]:-<none>}" >&2
    exit 1
  fi
  printf '%s\n' "${matches[0]}"
}

DARWIN_TGZ="$(require_exactly_one "macOS .app.tar.gz" artifacts/macos/*.app.tar.gz)"
DARWIN_SIG_FILE="$(require_exactly_one "macOS .app.tar.gz.sig" artifacts/macos/*.app.tar.gz.sig)"
DARWIN_SIG="$(cat "$DARWIN_SIG_FILE")"
DARWIN_NAME="$(basename "$DARWIN_TGZ")"
DARWIN_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${DARWIN_NAME}"

WIN_EXE="$(require_exactly_one "Windows -setup.exe" artifacts/windows/*-setup.exe)"
WIN_SIG_FILE="$(require_exactly_one "Windows -setup.exe.sig" artifacts/windows/*-setup.exe.sig)"
WIN_SIG="$(cat "$WIN_SIG_FILE")"
WIN_NAME="$(basename "$WIN_EXE")"
WIN_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${WIN_NAME}"

jq -n \
  --arg v "$VERSION" \
  --arg notes "$NOTES" \
  --arg pub "$PUB_DATE" \
  --arg dsig "$DARWIN_SIG" \
  --arg durl "$DARWIN_URL" \
  --arg wsig "$WIN_SIG" \
  --arg wurl "$WIN_URL" \
  '{
    version: $v,
    notes: $notes,
    pub_date: $pub,
    platforms: {
      "darwin-aarch64": { signature: $dsig, url: $durl },
      "windows-x86_64": { signature: $wsig, url: $wurl }
    }
  }' > latest.json

echo "Composed latest.json:"
cat latest.json
