#!/bin/bash
# Run every local quality gate: strict build, unit tests, shell lint, and
# a check that Resources/shotgun.wav still matches its generator.
#   bash scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ Strict build (warnings are errors)…"
swift build -c release -Xswiftc -warnings-as-errors

# With only the Command Line Tools installed (no Xcode), SwiftPM doesn't
# put the bundled swift-testing framework on its search paths.
TEST_FLAGS=()
CLT=/Library/Developer/CommandLineTools
if [ "$(xcode-select -p 2>/dev/null)" = "$CLT" ]; then
  FW="$CLT/Library/Developer/Frameworks"
  LIB="$CLT/Library/Developer/usr/lib"
  TEST_FLAGS=(
    -Xswiftc -F -Xswiftc "$FW"
    -Xlinker -F -Xlinker "$FW"
    -Xlinker -rpath -Xlinker "$FW"
    -Xlinker -rpath -Xlinker "$LIB"
  )
fi
echo "▸ Unit tests…"
swift test "${TEST_FLAGS[@]+"${TEST_FLAGS[@]}"}"

if command -v shellcheck >/dev/null 2>&1; then
  echo "▸ shellcheck…"
  shellcheck build.sh scripts/*.sh
else
  echo "▸ shellcheck not installed — skipping (brew install shellcheck)"
fi

echo "▸ Verifying shotgun.wav is reproducible from scripts/generate_sound.py…"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts"
cp scripts/generate_sound.py "$TMP/scripts/"
python3 "$TMP/scripts/generate_sound.py" >/dev/null
cmp "$TMP/Resources/shotgun.wav" Resources/shotgun.wav

echo "✅ All checks passed"
