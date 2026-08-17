#!/bin/bash
# One-time setup: create a self-signed code-signing certificate so that
# rebuilds keep a stable signature. Why you want this: macOS pins the
# Input Monitoring permission to the app's signature, and ad-hoc
# signatures change on every build — a stable identity means you grant
# the permission once and never again.
#
# Run this yourself (it touches your keychain, so it may show one or
# two system dialogs — approve them):
#   bash scripts/setup-signing.sh
#
# Afterwards build.sh picks the certificate up automatically.
set -euo pipefail

NAME="ShotgunKeystroke Dev Signing"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "✅ '$NAME' already exists — nothing to do."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "▸ Generating self-signed code-signing certificate…"
openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -days 3650 -nodes -subj "/CN=$NAME" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false" 2>/dev/null

# -legacy: macOS's keychain importer can't read modern OpenSSL 3 p12
# encodings. LibreSSL lacks the flag, hence the fallback.
echo "▸ Packaging as p12…"
openssl pkcs12 -export -legacy -out "$TMP/sk.p12" -inkey "$TMP/key.pem" \
  -in "$TMP/cert.pem" -passout pass:shotgun -name "$NAME" 2>/dev/null \
  || openssl pkcs12 -export -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES \
       -macalg sha1 -out "$TMP/sk.p12" -inkey "$TMP/key.pem" \
       -in "$TMP/cert.pem" -passout pass:shotgun -name "$NAME"

echo "▸ Importing into your login keychain…"
security import "$TMP/sk.p12" -k ~/Library/Keychains/login.keychain-db \
  -P shotgun -T /usr/bin/codesign

echo "▸ Trusting it for code signing (approve the dialog if one appears)…"
security add-trusted-cert -r trustRoot -p codeSign \
  -k ~/Library/Keychains/login.keychain-db "$TMP/cert.pem"

# The identity change strands any existing Input Monitoring grant;
# clear it once so the next launch shows a fresh prompt.
tccutil reset ListenEvent dev.piyush.shotgunkeystroke >/dev/null 2>&1 || true

echo
security find-identity -v -p codesigning
echo
echo "✅ Done. Now run: ./build.sh && open build/ShotgunKeystroke.app"
echo "   First signing may show a keychain prompt — click 'Always Allow'."
echo "   Grant Input Monitoring one last time; rebuilds will keep it from now on."
