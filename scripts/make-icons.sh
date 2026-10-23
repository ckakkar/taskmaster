#!/usr/bin/env bash
# Renders the app icon from Miso's atlas and packs it into Resources/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
iconset="$work/AppIcon.iconset"
swift -module-cache-path .build/module-cache scripts/render-icon.swift "$iconset"
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
cp "$iconset/icon_512x512@2x.png" Resources/AppIcon.png
rm -rf "$work"
echo "› Resources/AppIcon.icns"
