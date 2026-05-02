#!/usr/bin/env bash
# Compose latest.json from the macOS/windows bundles + their .sig files.
# Inputs (env): GITHUB_REF, GITHUB_REPOSITORY.
# Inputs (files): artifacts/macos/*.app.tar.gz + .sig, artifacts/windows/*-setup.exe + .sig, CHANGELOG.md.
# Output: latest.json in CWD.
set -euo pipefail

VERSION="${GITHUB_REF#refs/tags/v}"
REPO="${GITHUB_REPOSITORY}"
PUB_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Extract release notes from the section under "## [VERSION]" until the
# next "## [" heading (or EOF). Strips the heading itself and trims trailing
# blank lines.
NOTES="$(awk -v ver="## \\[$VERSION\\]" '
  $0 ~ ver { capture=1; next }
  capture && /^## \[/ { exit }
  capture { print }
' CHANGELOG.md | sed -e :a -e '/^\s*$/{$d;N;ba' -e '}')"

# Resolve artifact paths and read .sig contents.
DARWIN_TGZ="$(ls artifacts/macos/*.app.tar.gz | head -n1)"
DARWIN_SIG="$(cat artifacts/macos/*.app.tar.gz.sig)"
DARWIN_NAME="$(basename "$DARWIN_TGZ")"
DARWIN_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${DARWIN_NAME}"

WIN_EXE="$(ls artifacts/windows/*-setup.exe | head -n1)"
WIN_SIG="$(cat artifacts/windows/*-setup.exe.sig)"
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
