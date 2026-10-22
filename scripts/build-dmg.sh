#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASKMASTER_STAGE="build/dmg-stage"
mkdir -p "$TASKMASTER_STAGE"
ditto build/Taskmaster.app "$TASKMASTER_STAGE/Taskmaster.app"
ln -sfn /Applications "$TASKMASTER_STAGE/Applications"
hdiutil create -volname Taskmaster -srcfolder "$TASKMASTER_STAGE" -ov -format UDZO build/Taskmaster.dmg
printf '\nPackaged build/Taskmaster.dmg\n'
