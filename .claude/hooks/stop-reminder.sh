#!/usr/bin/env bash
# stop-reminder.sh — Stop hook
# Reminds Claude to run /verify if there are uncommitted source changes.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || exit 0
if ! git diff --quiet -- src/ src-tauri/src/ 2>/dev/null \
   || ! git diff --cached --quiet -- src/ src-tauri/src/ 2>/dev/null; then
  echo "Source files changed this session. Run /verify before claiming done." >&2
fi
exit 0
