#!/bin/bash
# StandoffCheat shellswap — place the cheat inside a REAL framework the game already loads.
#
# Detection model being defeated: Standoff 2's integrity checker flags any UNKNOWN module,
# file, or load-command injected into the app (dylib adds = instant permanent ban).
# Shellswap keeps the module list, install names, bundle contents and in-memory image names
# byte-for-byte identical to stock by REPLACING the Mach-O of a real framework the game
# eagerly loads with a rebuilt binary that:
#   - carries OUR cheat code (constructor, worker, menu, esp, aimbot...)
#   - re-exports every symbol the original framework exported (as inert stubs)
#   - keeps the original LC_ID_DYLIB (e.g. @rpath/AppMetricaLog.framework/AppMetricaLog)
#
# Usage: ./shellswap.sh input.ipa [target_framework] [output.ipa]
#   target_framework defaults to AppMetricaLog (logging-only → stubbing is safe).
# macOS only. Needs Xcode toolchain.

set -e

IPA="${1:?Usage: ./shellswap.sh input.ipa [target_framework] [output.ipa]}"
TARGET="${2:-AppMetricaLog}"
OUT_IPA="${3:-${IPA%.ipa}-shell.ipa}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR"
WORK="$(mktemp -d)"

case "$OUT_IPA" in
    /*) : ;;
    *) OUT_IPA="$(pwd)/$OUT_IPA" ;;
esac
mkdir -p "$(dirname "$OUT_IPA")"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v nm >/dev/null 2>&1 || { echo "ERROR: nm not found" >&2; exit 1; }
command -v codesign >/dev/null 2>&1 || { echo "ERROR: codesign not found" >&2; exit 1; }

echo "==> Extracting IPA"
unzip -q "$IPA" -d "$WORK/app"
APP_DIR="$(find "$WORK/app" -maxdepth 2 -name '*.app' -type d | head -1)"
[ -n "$APP_DIR" ] || { echo "ERROR: no .app found in IPA" >&2; exit 1; }

FW_DIR="$APP_DIR/Frameworks/$TARGET.framework"
FW_BIN="$FW_DIR/$TARGET"
[ -f "$FW_BIN" ] || { echo "ERROR: $FW_BIN not found. Not a valid shell target for this IPA." >&2; exit 1; }

echo "    Target: $TARGET.framework/$TARGET ($(stat -f%z "$FW_BIN") bytes)"

# Choose the arm64 slice's symbol view. Xcode nm handles thin/fat; force arm64.
NM_ARGS="-arch arm64"
if nm $NM_ARGS "$FW_BIN" >/dev/null 2>&1; then :; else NM_ARGS=""; fi
if nm $NM_ARGS -gU "$FW_BIN" >/dev/null 2>&1; then :; else NM_ARGS=""; fi

ORIG_ID="$(otool -D "$FW_BIN" 2>/dev/null | tail -1)"
[ -n "$ORIG_ID" ] && [[ "$ORIG_ID" == @* ]] || ORIG_ID="@rpath/$TARGET.framework/$TARGET"
echo "    Original dylib ID: $ORIG_ID"

echo "==> Harvesting exported symbols"
nm $NM_ARGS -gU "$FW_BIN" 2>/dev/null | awk '{$1="";print}' | tr -d ' ' \
  | grep '^_' | sort -u > "$WORK/orig_syms.txt"
echo "    $(wc -l < "$WORK/orig_syms.txt") exported symbols"

echo "==> Generating stub runtime"
GEN="$WORK/stubs.mm"
{
    echo '// AUTO-GENERATED symbol-compat stubs for'
    echo "// $TARGET.framework/$TARGET"
    echo '// Every exported C function -> no-op returning 0'
    echo '// Every exported ObjC class -> empty @interface/@implementation'
    echo '// Exported globals -> zeroed definitions'
    echo '#import <Foundation/Foundation.h>'
} > "$GEN"

declare -a CLASSES
while IFS= read -r sym; do
    case "$sym" in
        _OBJC_CLASS_\$_*)
            cls="${sym#_OBJC_CLASS_$_}"
            # strip any mangled suffix like "$." (category classes etc.)
            cls=$(echo "$cls" | sed 's/[^A-Za-z0-9_]/_/g')
            [ -n "$cls" ] && CLASSES+=("$cls")
            ;;
        _OBJC_METACLASS_\$_*|_OBJC_IVAR_\$_*|_OBJC_INSTANCE_VARIABLES_*)
            ;;  # implied by @implementation / not needed
        _fatal_error|_FSReadStream|__*)
            ;;  # reserved / don't touch
        *)
            stem="${sym#_}"
            stem=$(echo "$stem" | sed 's/[^A-Za-z0-9_]/_/g')
            [ -n "$stem" ] && printf 'extern "C" __attribute__((used)) void* %s() { return 0; }\n' "$stem" >> "$GEN"
            ;;
    esac
done < "$WORK/orig_syms.txt"

printf '%s\n' "${CLASSES[@]:-}" | sort -u | grep -v '^$' | while read -r cls; do
    printf '@interface %s : NSObject @end\n@implementation %s\n@end\n' "$cls" "$cls" >> "$GEN"
done

echo "    $(grep -c '@interface' "$GEN") ObjC class stubs, $(grep -c 'void\* .*()' "$GEN") C stubs"

echo "==> Building shell dylib"
SDK="${SDK:-$(xcrun --sdk iphoneos --show-sdk-path)}"
CLANG="$(xcrun --find clang)"
ARCH="${ARCH:-arm64}"
MIN_IOS="${MIN_IOS:-12.0}"
INCDIR="$SRC_DIR/include"
SRCDIR="$SRC_DIR/src"
mkdir -p "$SRC_DIR/build"

$CLANG -x objective-c++ \
  -arch "$ARCH" \
  -isysroot "$SDK" \
  -miphoneos-version-min="$MIN_IOS" \
  -fobjc-arc \
  -fobjc-runtime=ios \
  -O2 \
  -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable \
  -I"$INCDIR" -I"$SRCDIR" \
  -dynamiclib \
  -undefined dynamic_lookup \
  -install_name "$ORIG_ID" \
  -framework UIKit \
  -framework Foundation \
  -framework CoreGraphics \
  -framework QuartzCore \
  -framework CoreText \
  -o "$WORK/$TARGET" \
  "$GEN" \
  "$SRCDIR/main.mm" \
  "$SRCDIR/il2cpp_resolver.mm" \
  "$SRCDIR/tracelog.mm" \
  "$SRCDIR/w2s.mm" \
  "$SRCDIR/esp.mm" \
  "$SRCDIR/aimbot.mm" \
  "$SRCDIR/menu.mm" \
  "$SRCDIR/recoil.mm" \
  "$SRCDIR/overlay.mm"

echo "    Shell size: $(stat -f%z "$WORK/$TARGET") bytes"

echo "==> Verifying symbol coverage vs original"
nm $NM_ARGS -gU "$WORK/$TARGET" 2>/dev/null | awk '{$1="";print}' | tr -d ' ' | grep '^_' | sort -u > "$WORK/new_syms.txt"
MISSING="$(comm -23 "$WORK/orig_syms.txt" "$WORK/new_syms.txt" | grep -v '_OBJC_IVAR_' || true)"
if [ -n "$MISSING" ]; then
    echo "    WARNING: $(echo "$MISSING" | wc -l | tr -d ' ') original exports not reproduced:"
    echo "$MISSING" | head -20 | sed 's/^/        /'
else
    echo "    All original exports reproduced. ✓"
fi

echo "==> Swapping binary into framework"
mv "$FW_BIN" "$FW_DIR/$TARGET.orig" 2>/dev/null || true
rm -rf "$FW_DIR/_CodeSignature" || true
cp "$WORK/$TARGET" "$FW_BIN"
chmod +x "$FW_BIN"
install_name_tool -id "$ORIG_ID" "$FW_BIN" 2>/dev/null || true
# keep original flags on the framework binary for fidelity
mkdir -p "$FW_DIR/SC_Info" 2>/dev/null || true

echo "==> Re-signing all binaries + frameworks"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-$([ -z "$RELEASE_SIGNING_IDENTITY" ] && echo "iPhone Developer" || echo "$RELEASE_SIGNING_IDENTITY")}"
echo "    Identity: $CODE_SIGN_IDENTITY"

find "$APP_DIR/Frameworks" -name '*.framework' -maxdepth 1 -type d | while read -r fw; do
    codesign --force --sign "$CODE_SIGN_IDENTITY" "$fw" 2>/dev/null || \
    codesign --force --sign - "$fw" 2>/dev/null || true
done

MAIN_BIN="$APP_DIR/Standoff2"
[ -f "$MAIN_BIN" ] || MAIN_BIN="$(find "$APP_DIR" -maxdepth 1 -type f -perm -111 | head -1)"
codesign --force --sign "-" "$MAIN_BIN" 2>/dev/null || true
rm -f "$APP_DIR/embedded.mobileprovision" || true
codesign --force --sign - --preserve-metadata=entitlements,identifier,flags --deep "$APP_DIR" 2>/dev/null || \
codesign --force --sign - --deep "$APP_DIR" 2>/dev/null || true

echo "==> Repackaging IPA"
( cd "$WORK/app" && zip -qy -r "$OUT_IPA" Payload ) 2>/dev/null || \
( cd "$WORK/app" && zip -qy -r "$OUT_IPA" . )

echo ""
echo "==> DONE: $OUT_IPA"
echo "    Cheat now lives inside $TARGET.framework — no injected module, no extra file."
echo "    Sideload normally with E-sign / Sideloadly."