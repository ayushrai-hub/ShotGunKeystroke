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

# Use a stable signing identity if you have one (survives rebuilds so
# macOS keeps your Input Monitoring grant):
#   CODESIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" ./build.sh
IDENTITY="${CODESIGN_IDENTITY:--}"
echo "▸ Signing (identity: $IDENTITY)…"
codesign --force --sign "$IDENTITY" "$APP"

if [ "$IDENTITY" = "-" ]; then
  # Ad-hoc signatures change on every build, which strands any previous
  # Input Monitoring grant (symptom: modifier keys fire, letters don't).
  # Clear the stale TCC entry so the next launch shows a fresh one-click
  # permission prompt instead of silently half-working.
  echo "▸ Clearing stale Input Monitoring grant (ad-hoc signature changed)…"
  tccutil reset ListenEvent dev.piyush.shotgunkeystroke || true
fi

echo "✅ Built $APP"
echo "   Run it with: open $APP"
