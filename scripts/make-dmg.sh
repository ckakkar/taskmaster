#!/usr/bin/env bash
# Packs Taskmaster.app into a disk image whose window shows Taskmaster, a trail of pawprints and
# Applications on a desk (scripts/dmg-background.swift), with Taskmaster's icon as the volume icon.
#
#   scripts/make-dmg.sh <Taskmaster.app> <Taskmaster.dmg>
#
# The window layout is written by dmgbuild (installed into .build/dmg-venv on first use), which needs no
# Finder scripting and so works the same locally and in CI.
set -euo pipefail
cd "$(dirname "$0")/.."
app=$1
dmg=$2

venv=.build/dmg-venv
if [[ ! -x "$venv/bin/dmgbuild" ]]; then
    python3 -m venv "$venv"
    "$venv/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==1.6.*"
fi

work=build/dmg
mkdir -p "$work" .build/module-cache
swift -module-cache-path .build/module-cache scripts/dmg-background.swift "$work/background.png" 1
swift -module-cache-path .build/module-cache scripts/dmg-background.swift "$work/background@2x.png" 2
tiffutil -cathidpicheck "$work/background.png" "$work/background@2x.png" -out "$work/background.tiff" 2>/dev/null

rm -f "$dmg"
"$venv/bin/dmgbuild" -s scripts/dmg-settings.py -D app="$app" -D background="$work/background.tiff" \
    -D icon=Resources/AppIcon.icns "Taskmaster" "$dmg" >/dev/null
echo "› $dmg"
