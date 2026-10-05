#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "usage: $0 <version>, for example $0 0.3.0" >&2
  exit 64
fi

version="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
release_dir="$root/build/macos/Build/Products/Release"
app_name="Swiftie Quiz.app"
app="$release_dir/$app_name"
out_dir="$root/build/release"
dmg="$out_dir/Swiftie Quiz_${version}_aarch64.dmg"
archive="$out_dir/Swiftie Quiz.app.tar.gz"

if [ ! -d "$app" ]; then
  echo "error: $app is missing; run flutter build macos --release first" >&2
  exit 1
fi

mkdir -p "$out_dir"
codesign --force --deep --sign - "$app"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/$app_name"
ln -s /Applications "$staging/Applications"

rm -f "$dmg"
for attempt in 1 2 3; do
  if hdiutil create -volname "Swiftie Quiz" -srcfolder "$staging" -ov -format UDZO "$dmg"; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "error: hdiutil could not create $dmg" >&2
    exit 1
  fi
  sleep 5
done

rm -f "$archive"
COPYFILE_DISABLE=1 tar -czf "$archive" -C "$release_dir" "$app_name"

echo "$dmg"
echo "$archive"
