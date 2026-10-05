#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
file=$(jq -r '.tool_input.file_path // ""' <<<"$input")
[[ -n "$file" && -f "$file" ]] || exit 0

root=${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
relative=${file#"$root"/}
case "$relative" in
  lib/*.dart) ;;
  *) exit 0 ;;
esac

if matches=$(grep -nE '(^|[^A-Za-z0-9_$.])(print|debugPrint)\(' "$file"); then
  echo "WARNING: print or debugPrint in $relative. lib/ must not print; only tests may:" >&2
  echo "$matches" >&2
  exit 2
fi
exit 0
