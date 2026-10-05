#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
paths=(lib/ test/ tool/ installer/ assets/ pubspec.yaml)

if ! git -C "$root" diff --quiet -- "${paths[@]}" 2>/dev/null \
   || ! git -C "$root" diff --cached --quiet -- "${paths[@]}" 2>/dev/null \
   || [[ -n "$(git -C "$root" ls-files --others --exclude-standard -- "${paths[@]}" 2>/dev/null)" ]]; then
  echo "App sources changed this session. Run /verify (dart format, flutter analyze --fatal-infos, flutter test) before claiming done." >&2
fi
exit 0
