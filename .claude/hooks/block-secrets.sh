#!/usr/bin/env bash
# block-secrets.sh — PreToolUse blocking hook
# Refuses Write/Edit if the new content contains common secret patterns.

set -euo pipefail
input=$(cat)
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')
[[ -z "$content" ]] && exit 0

patterns=(
  'sk-[A-Za-z0-9]{32,}'
  'Bearer [A-Za-z0-9_\-\.]{20,}'
  'AKIA[0-9A-Z]{16}'
  'ghp_[A-Za-z0-9]{36}'
  'github_pat_[A-Za-z0-9_]{82}'
  '(API_KEY|SECRET|PASSWORD|TOKEN)[[:space:]]*[:=][[:space:]]*['\''"][^'\''"]{16,}['\''"]'
)
for pat in "${patterns[@]}"; do
  if echo "$content" | grep -qE "$pat"; then
    echo "BLOCKED: edit contains a secret matching: $pat" >&2
    echo "If false-positive: override in .claude/settings.local.json, or move to .env" >&2
    exit 1
  fi
done
exit 0
