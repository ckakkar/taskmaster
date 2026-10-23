#!/usr/bin/env bash
# Builds Taskmaster.app from the Swift package; there is no Xcode project.
#
#   scripts/build-app.sh [--debug] [--universal] [--version X.Y.Z] [--build N] [--out DIR]
#
# --universal  one binary for Apple Silicon and Intel
# --version    defaults to <major.minor from Resources/Info.plist>.<commits on HEAD>, like Luna
# --build      CFBundleVersion, which Sparkle compares; defaults to the number of commits on HEAD
#
# Signing: TASKMASTER_SIGN_IDENTITY if set; otherwise a "Taskmaster Self-Signed" certificate from the keychain
# if there is one (a stable identity keeps the app's identity, and anything macOS has granted it, across
# updates); otherwise ad-hoc. With a Developer ID identity the app is signed with the hardened runtime,
# ready for notarization.
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"

config=release
universal=0
version=""
build_number=""
out=build
while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug) config=debug ;;
        --universal) universal=1 ;;
        --version) version="$2"; shift ;;
        --build) build_number="$2"; shift ;;
        --out) out="$2"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

base=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
build_number=${build_number:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}
version=${version:-$base.$build_number}

echo "› Building Taskmaster $version ($config$([[ $universal == 1 ]] && echo ', universal'))"
arch_flags=()
if [[ $universal == 1 ]]; then arch_flags=(--arch arm64 --arch x86_64); fi
swift build -c "$config" "${arch_flags[@]}" --product Taskmaster --disable-sandbox
products=$(swift build -c "$config" "${arch_flags[@]}" --show-bin-path --disable-sandbox)
binary="$products/Taskmaster"
archs=$(lipo -archs "$binary")
if [[ $universal == 1 && ! ( $archs == *arm64* && $archs == *x86_64* ) ]]; then
    echo "error: $binary isn't universal ($archs)" >&2
    exit 1
fi

app="$out/Taskmaster.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$binary" "$app/Contents/MacOS/Taskmaster"
# The character art and its metadata, which PetAtlas looks for in Contents/Resources.
for resource in "$products"/*.bundle; do
    [[ -d "$resource" ]] && ditto "$resource" "$app/Contents/Resources/$(basename "$resource")"
done

plist="$app/Contents/Info.plist"
cp Resources/Info.plist "$plist"
plutil -replace CFBundleShortVersionString -string "$version" "$plist"
plutil -replace CFBundleVersion -string "$build_number" "$plist"
if [[ -s Resources/SparklePublicKey.txt ]]; then
    plutil -replace SUPublicEDKey -string "$(tr -d '[:space:]' < Resources/SparklePublicKey.txt)" "$plist"
fi

if [[ ! -f Resources/AppIcon.icns ]]; then scripts/make-icons.sh; fi
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

sparkle=$(find "$products" .build/artifacts -name Sparkle.framework -maxdepth 6 -type d 2>/dev/null | head -1)
ditto "$sparkle" "$app/Contents/Frameworks/Sparkle.framework"

identity=${TASKMASTER_SIGN_IDENTITY:-}
# Self-signed certificates aren't "valid" to `find-identity -v` (nobody vouches for them), so no -v.
if [[ -z "$identity" ]] && security find-identity -p codesigning 2>/dev/null | grep -q "Taskmaster Self-Signed"; then
    identity="Taskmaster Self-Signed"
fi
identity=${identity:--}
flags=(--force --sign "$identity")
if [[ "$identity" == Developer\ ID* ]]; then flags+=(--options runtime --timestamp); fi

# Inside out: Sparkle's helpers, the framework, then the app.
fw="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in "$fw/XPCServices/Installer.xpc" "$fw/XPCServices/Downloader.xpc"; do
    [[ -e "$item" ]] && codesign "${flags[@]}" --preserve-metadata=entitlements "$item"
done
for item in "$fw/Autoupdate" "$fw/Updater.app" "$app/Contents/Frameworks/Sparkle.framework"; do
    [[ -e "$item" ]] && codesign "${flags[@]}" "$item"
done
codesign "${flags[@]}" "$app"
codesign --verify --deep --strict "$app"

echo "› $app (signed: $([[ "$identity" == "-" ]] && echo ad-hoc || echo "$identity"))"
