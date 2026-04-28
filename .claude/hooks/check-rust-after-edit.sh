#!/usr/bin/env bash
# check-rust-after-edit.sh — PostToolUse, non-blocking
# Runs cargo check on the manifest after a Rust file edit.

set -euo pipefail
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""')
case "$file" in *src-tauri/src/*.rs) ;; *) exit 0 ;; esac
cd "$(git rev-parse --show-toplevel)/src-tauri"
if ! out=$(cargo check --message-format=short 2>&1); then
  echo "cargo check failed after edit to $file:" >&2
  echo "$out" | tail -30 >&2
fi
exit 0
