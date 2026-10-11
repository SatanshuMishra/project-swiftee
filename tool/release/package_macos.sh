#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ] || ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]] || ! [[ "$2" =~ ^(ana|open)$ ]]; then
  echo "usage: $0 <version> <ana|open>, for example $0 0.3.0 open" >&2
  exit 64
fi

version="$1"
edition="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
release_dir="$root/build/macos/Build/Products/Release"
built_app="$release_dir/Project Swiftie.app"
out_dir="$root/build/release"

if [ ! -d "$built_app" ]; then
  echo "error: $built_app is missing; run flutter build macos --release first" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ "$edition" = "ana" ]; then
  product="Project Swiftie Ana"
  source_dir="$work/app"
  app_name="$product.app"
  mkdir "$source_dir"
  ditto "$built_app" "$source_dir/$app_name"
  plist="$source_dir/$app_name/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.swiftiequiz.desktop.ana" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $product" "$plist"
  if /usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $product" "$plist"
  else
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $product" "$plist"
  fi
else
  product="Project Swiftie"
  source_dir="$release_dir"
  app_name="$product.app"
fi

app="$source_dir/$app_name"
dmg="$out_dir/${product}_${version}_aarch64.dmg"
archive="$out_dir/$app_name.tar.gz"

codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"

mkdir -p "$out_dir"
staging="$work/dmg"
mkdir "$staging"
ditto "$app" "$staging/$app_name"
ln -s /Applications "$staging/Applications"

rm -f "$dmg"
for attempt in 1 2 3; do
  if hdiutil create -volname "$product" -srcfolder "$staging" -ov -format UDZO "$dmg"; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "error: hdiutil could not create $dmg" >&2
    exit 1
  fi
  sleep 5
done

rm -f "$archive"
COPYFILE_DISABLE=1 tar -czf "$archive" -C "$source_dir" "$app_name"

echo "$dmg"
echo "$archive"
