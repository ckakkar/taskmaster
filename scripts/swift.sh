#!/bin/bash
# Keep SwiftPM's caches local and support both Swift Testing installation layouts.
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"

TASKMASTER_OPERATION="${1:-build}"
if [ "$#" -gt 0 ]; then shift; fi
TASKMASTER_FLAGS=(--build-system native --disable-sandbox --scratch-path .build
  --cache-path .build/cache --config-path .build/config --security-path .build/security
  -Xswiftc -module-cache-path -Xswiftc "$PWD/.build/module-cache")

if [ "$TASKMASTER_OPERATION" = test ]; then
  TASKMASTER_DEVELOPER="$(xcode-select -p)"
  TASKMASTER_TOOLCHAIN="$(dirname "$(dirname "$(xcrun --find swift)")")"
  for frameworks in "$TASKMASTER_DEVELOPER/Library/Developer/Frameworks" \
      "$TASKMASTER_DEVELOPER/Platforms/MacOSX.platform/Developer/Library/Frameworks"; do
    if [ -d "$frameworks/Testing.framework" ]; then
      TASKMASTER_FLAGS+=(-Xswiftc -F -Xswiftc "$frameworks" -Xlinker -rpath -Xlinker "$frameworks")
      break
    fi
  done
  TASKMASTER_TEST_PLUGIN="$TASKMASTER_TOOLCHAIN/lib/swift/host/plugins/testing/libTestingMacros.dylib"
  if [ -f "$TASKMASTER_TEST_PLUGIN" ]; then
    TASKMASTER_FLAGS+=(-Xswiftc -load-plugin-library -Xswiftc "$TASKMASTER_TEST_PLUGIN")
  fi
fi

exec swift "$TASKMASTER_OPERATION" "${TASKMASTER_FLAGS[@]}" "$@"
