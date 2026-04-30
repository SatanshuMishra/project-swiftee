#!/usr/bin/env bash
# warn-console-log.sh — PostToolUse non-blocking warning
# Flags console.* statements in src/ production code.

set -euo pipefail
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""')
case "$file" in
  *src/*.ts|*src/*.tsx) ;;
  *) exit 0 ;;
esac
case "$file" in
  *.test.ts|*.test.tsx|*test-setup*) exit 0 ;;
esac
[[ -f "$file" ]] || exit 0
if grep -nE 'console\.(log|warn|error|debug|info)' "$file" >/dev/null 2>&1; then
  echo "WARNING: console.* in $file (project rule 4 — tests only):" >&2
  grep -nE 'console\.(log|warn|error|debug|info)' "$file" >&2
fi
exit 0
