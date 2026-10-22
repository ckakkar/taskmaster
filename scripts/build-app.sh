#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"

./scripts/swift.sh build -c release

TASKMASTER_BIN_DIR="$(./scripts/swift.sh build -c release --show-bin-path)"
TASKMASTER_APP="build/Taskmaster.app"
mkdir -p "$TASKMASTER_APP/Contents/MacOS" "$TASKMASTER_APP/Contents/Resources"
cp "$TASKMASTER_BIN_DIR/Taskmaster" "$TASKMASTER_APP/Contents/MacOS/Taskmaster"
for resource in "$TASKMASTER_BIN_DIR"/*.bundle; do
  [ ! -d "$resource" ] || cp -R "$resource" "$TASKMASTER_APP/Contents/Resources/"
done
cp Resources/Info.plist "$TASKMASTER_APP/Contents/Info.plist"
swift -module-cache-path .build/module-cache scripts/render-icon.swift
iconutil -c icns build/Taskmaster.iconset -o "$TASKMASTER_APP/Contents/Resources/Taskmaster.icns"
codesign --force --deep --sign - "$TASKMASTER_APP"
printf '\nBuilt %s\n' "$TASKMASTER_APP"
