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

# Use a stable signing identity if available (survives rebuilds so
# macOS keeps your Input Monitoring grant). Create one with:
#   bash scripts/setup-signing.sh
# or point at your own: CODESIGN_IDENTITY="Apple Development: …" ./build.sh
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "ShotgunKeystroke Dev Signing"; then
    IDENTITY="ShotgunKeystroke Dev Signing"
  else
    IDENTITY="-"
  fi
fi
echo "▸ Signing (identity: $IDENTITY, hardened runtime)…"
# Hardened runtime blocks DYLD_INSERT_LIBRARIES-style code injection, so
# other local code can't piggyback on this app's Input Monitoring grant.
codesign --force --options runtime --sign "$IDENTITY" "$APP"

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
