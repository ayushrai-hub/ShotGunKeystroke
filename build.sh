#!/bin/bash
# Build ShotgunKeystroke.app from source. No Xcode project needed —
# just the Swift toolchain (comes with Xcode or the Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="ShotgunKeystroke"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "▸ Building $APP_NAME (release)…"
swift build -c release

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp Resources/shotgun.wav "$APP/Contents/Resources/"

echo "▸ Signing (ad-hoc)…"
codesign --force --sign - "$APP"

echo "✅ Built $APP"
echo "   Run it with: open $APP"
