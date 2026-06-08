#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
PRODUCT_NAME="MarkdoneViewer"
BUNDLE_NAME="Markdone Viewer.app"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$PRODUCT_NAME"
APP_DIR="$ROOT_DIR/build/$BUNDLE_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

codesign --force --sign - "$APP_DIR"

echo "$APP_DIR"
