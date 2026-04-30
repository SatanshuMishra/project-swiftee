#!/usr/bin/env bash
# block-csp-weakening.sh — PreToolUse blocking hook
# Refuses changes to tauri.conf.json or capabilities/*.json that weaken security.

set -euo pipefail
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""')
case "$file" in
  *src-tauri/tauri.conf.json|*src-tauri/capabilities/*.json) ;;
  *) exit 0 ;;
esac
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')

violations=()
echo "$content" | grep -qE '"dangerousDisableAssetCspModification"[[:space:]]*:[[:space:]]*true' \
  && violations+=("dangerousDisableAssetCspModification flipped to true")
echo "$content" | grep -qE "unsafe-(eval|inline)" \
  && violations+=("CSP contains unsafe-eval or unsafe-inline")
echo "$content" | grep -qE "default-src[^;]*[[:space:]]\\*([[:space:]]|;|\\\"|$)" \
  && violations+=("CSP default-src wildcard '*'")

for origin in "https://lrclib.net" "https://api.deezer.com" "dzcdn.net"; do
  echo "$content" | grep -qF "$origin" || violations+=("Required origin removed: $origin")
done

if (( ${#violations[@]} > 0 )); then
  echo "BLOCKED: Tauri security regression in $file" >&2
  printf '  - %s\n' "${violations[@]}" >&2
  echo "Document justification in docs/decisions/ before retrying." >&2
  exit 1
fi
exit 0
