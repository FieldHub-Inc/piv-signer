#!/bin/bash
# Notarize a built .app for distribution outside the Mac App Store.
#
# Prerequisites:
#   1. The bundle must be signed with a Developer ID Application identity:
#        SIGN_IDENTITY="Developer ID Application: FieldHub Inc. (TEAMID)" \
#          ./Scripts/build-app.sh
#   2. An app-specific password from https://appleid.apple.com → Sign-In and
#      Security → App-Specific Passwords. Optionally store it in Keychain
#      under a profile name with:
#        xcrun notarytool store-credentials AC_PASSWORD \
#            --apple-id you@example.com --team-id TEAMID
#      then this script picks it up via NOTARY_PROFILE=AC_PASSWORD.
#
# Usage:
#   NOTARY_PROFILE=AC_PASSWORD ./Scripts/notarize.sh
#   APPLE_ID=... APPLE_TEAM_ID=... APPLE_APP_PASSWORD=... ./Scripts/notarize.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/PIV Signer.app}"
[ -d "$APP" ] || { echo "App bundle not found: $APP"; exit 1; }

# Verify the bundle is signed and hardened-runtime
echo "▸ Pre-flight: codesign verify"
codesign --verify --deep --strict --verbose=2 "$APP"

ZIP="$ROOT/dist/$(basename "$APP" .app).zip"
echo "▸ Zipping for upload"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "▸ Submitting to Apple notary service (this may take a few minutes)…"
if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$ZIP" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
else
    : "${APPLE_ID:?APPLE_ID env var is required}"
    : "${APPLE_TEAM_ID:?APPLE_TEAM_ID env var is required}"
    : "${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD env var is required}"
    xcrun notarytool submit "$ZIP" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait
fi

echo "▸ Stapling ticket to bundle"
xcrun stapler staple "$APP"

echo "▸ Validating staple"
spctl -a -t exec -vv "$APP" || true

echo "✓ Notarized: $APP"
