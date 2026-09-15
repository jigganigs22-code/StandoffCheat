#!/bin/bash
# StandoffCheat build script — macOS only (needs Xcode + iOS SDK)
# Usage: ./build.sh [path_to.ipa]

set -e

OUT="libgamedata.dylib"
SDK="${SDK:-$(xcrun --sdk iphoneos --show-sdk-path)}"
CLANG="$(xcrun --find clang)"
ARCH="${ARCH:-arm64}"
MIN_IOS="${MIN_IOS:-12.0}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> StandoffCheat build"
echo "    SDK:  $SDK"
echo "    Arch: $ARCH"

mkdir -p build

echo "==> Compiling objective-c++ sources..."

INCDIR="$SRC_DIR/include"
SRCDIR="$SRC_DIR/src"

$CLANG -x objective-c++ \
  -arch "$ARCH" \
  -isysroot "$SDK" \
  -miphoneos-version-min="$MIN_IOS" \
  -fobjc-arc \
  -fobjc-runtime=ios \
  -O2 \
  -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable \
  -I"$INCDIR" \
  -I"$SRCDIR" \
  -dynamiclib \
  -undefined dynamic_lookup \
  -Wl,-x \
  -Wl,-dead_strip \
  -Wl,-exported_symbols_list,"$SRC_DIR/export_symbols.list" \
  -install_name "@executable_path/Frameworks/$OUT" \
  -framework UIKit \
  -framework Foundation \
  -framework CoreGraphics \
  -framework QuartzCore \
  -framework CoreText \
  -o "build/$OUT" \
  "$SRCDIR/main.mm" \
  "$SRCDIR/il2cpp_resolver.mm" \
  "$SRCDIR/tracelog.mm" \
  "$SRCDIR/w2s.mm" \
  "$SRCDIR/esp.mm" \
  "$SRCDIR/aimbot.mm" \
  "$SRCDIR/menu.mm" \
  "$SRCDIR/recoil.mm" \
  "$SRCDIR/overlay.mm"

echo "==> Linking complete: build/$OUT"

if command -v insert_dylib > /dev/null 2>&1; then
    echo "    (insert_dylib available at $(command -v insert_dylib))"
fi

echo ""
echo "==> DONE. Inject into IPA:"
echo "    ./inject.sh [path_to.ipa]"