#!/bin/bash
# StandoffCheat injection script — macOS only
# Usage: ./inject.sh input.ipa [output.ipa]
# Requires: insert_dylib, codesign, and an iOS signing identity installed

set -e

IPA="${1:?Usage: ./inject.sh input.ipa [output.ipa]}"
OUT_IPA="${2:-${IPA%.ipa}-cheat.ipa}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DYLIB="$SCRIPT_DIR/build/StandoffCheat.dylib"
WORK="$(mktemp -d)"

case "$OUT_IPA" in
    /*) : ;;
    *) OUT_IPA="$(pwd)/$OUT_IPA" ;;
esac
mkdir -p "$(dirname "$OUT_IPA")"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

if [ ! -f "$DYLIB" ]; then
    echo "ERROR: $DYLIB not found. Run ./build.sh first." >&2
    exit 1
fi

command -v insert_dylib >/dev/null 2>&1 || { echo "ERROR: insert_dylib not installed" >&2; exit 1; }
command -v codesign >/dev/null 2>&1 || { echo "ERROR: codesign not found" >&2; exit 1; }

echo "==> Extracting IPA"
unzip -q "$IPA" -d "$WORK/app"
APP_DIR="$(find "$WORK/app" -maxdepth 2 -name '*.app' -type d | head -1)"
[ -n "$APP_DIR" ] || { echo "ERROR: no .app found in IPA" >&2; exit 1; }
echo "    App bundle: $APP_DIR"

echo "==> Copying dylib into Frameworks"
FRAMEWORKS="$APP_DIR/Frameworks"
mkdir -p "$FRAMEWORKS"
cp "$DYLIB" "$FRAMEWORKS/StandoffCheat.dylib"
install_name_tool -id "@executable_path/Frameworks/StandoffCheat.dylib" "$FRAMEWORKS/StandoffCheat.dylib" 2>/dev/null || true

MAIN_BIN="$APP_DIR/Standoff2"
if [ ! -f "$MAIN_BIN" ]; then
    MAIN_BIN="$APP_DIR/$(ls -1 "$APP_DIR" | grep -v '\.' | head -1)"
fi

echo "==> Injecting load command into $MAIN_BIN"
insert_dylib "@executable_path/Frameworks/StandoffCheat.dylib" "$MAIN_BIN" --inplace --all-yes

echo "==> Removing embedded provisioning (for sideload resign)"
rm -f "$APP_DIR/embedded.mobileprovision" || true

echo "==> Re-signing all binaries + frameworks"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-$([ -z "$RELEASE_SIGNING_IDENTITY" ] && echo "iPhone Developer" || echo "$RELEASE_SIGNING_IDENTITY")}"
echo "    Identity: $CODE_SIGN_IDENTITY"

# Sign dylib + frameworks first (reversed order matters)
codesign --force --sign "$CODE_SIGN_IDENTITY" "$FRAMEWORKS/StandoffCheat.dylib" 2>/dev/null || \
codesign --force --sign - "$FRAMEWORKS/StandoffCheat.dylib"

find "$FRAMEWORKS" -name '*.framework' -maxdepth 1 -type d | while read -r fw; do
    codesign --force --sign - "$fw" 2>/dev/null || true
done

codesign --force --sign - "$MAIN_BIN" 2>/dev/null || true
codesign --force --sign - --deep --preserve-metadata=entitlements,identifier,flags "$APP_DIR" 2>/dev/null || \
codesign --force --sign - --deep "$APP_DIR" 2>/dev/null || true

echo "==> Repackaging IPA"
( cd "$WORK/app" && zip -qy -r "$OUT_IPA" Payload ) 2>/dev/null || \
( cd "$WORK/app" && zip -qy -r "$OUT_IPA" . )

echo ""
echo "==> DONE: $OUT_IPA"
echo "    Sidelyload with Sideloadly / AltStore / TrollStore"