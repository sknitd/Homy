#!/usr/bin/env bash
# Builds Homy.app with Swift Package Manager (no Xcode project needed).
#
#   ./build.sh                 # release build for this Mac's architecture -> build/Homy.app
#   UNIVERSAL=1 ./build.sh     # arm64 + x86_64 universal binary
#   CONFIG=debug ./build.sh    # debug build
#   SIGN_IDENTITY="Developer ID Application: …" ./build.sh   # sign with a real identity
#   OPEN=1 ./build.sh          # launch the app when done
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Homy"
CONFIG="${CONFIG:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc signature
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
ICONSET_SRC="Resources/Assets.xcassets/AppIcon.appiconset"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "error: Homy is a macOS app; run this script on a Mac with Xcode 16+ installed." >&2
  exit 1
fi

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "==> Compiling ($CONFIG)…"
swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

echo "==> Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Building AppIcon.icns…"
if [[ ! -f "$ICONSET_SRC/icon_512x512@2x.png" ]] && command -v python3 >/dev/null; then
  python3 scripts/generate_icon.py
fi
TMP_ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$TMP_ICONSET"
cp "$ICONSET_SRC"/icon_*.png "$TMP_ICONSET/"
iconutil -c icns "$TMP_ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Compile the asset catalog too (accent color + icon) when actool is available.
if xcrun --find actool >/dev/null 2>&1; then
  xcrun actool "Resources/Assets.xcassets" \
    --compile "$APP/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --accent-color AccentColor \
    --output-partial-info-plist "$BUILD_DIR/assetcatalog-info.plist" >/dev/null || \
    echo "warning: actool failed; continuing with AppIcon.icns only"
fi

echo "==> Signing ($SIGN_IDENTITY)…"
codesign --force --deep --options runtime \
  --entitlements "Resources/Homy.entitlements" \
  --sign "$SIGN_IDENTITY" \
  "$APP"
codesign --verify --verbose=1 "$APP"

echo "==> Done: $APP"
if [[ "${OPEN:-0}" == "1" ]]; then
  open "$APP"
fi
