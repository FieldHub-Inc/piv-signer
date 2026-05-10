#!/bin/bash
# Build PIV Signer.app bundle from the Swift package binary.
# Usage:
#   ./Scripts/build-app.sh [release|debug]
#   SIGN_IDENTITY="Developer ID Application: ..." ./Scripts/build-app.sh
#
# Env vars:
#   SIGN_IDENTITY  Codesign identity. If unset, the bundle is unsigned.
#                  Use "Developer ID Application: ..." for outside-store
#                  notarization, or "Apple Distribution: ..." for Mac App
#                  Store submission.

set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="PIV Signer"
BUNDLE_ID="com.fieldhub.PivSigner"
VERSION="0.1.0"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT"

echo "▸ Building Swift package ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
EXEC="$BIN_PATH/PivSigner"
[ -x "$EXEC" ] || { echo "Binary not found at $EXEC"; exit 1; }

ICON_SRC="$ROOT/Sources/PivSigner/Resources/AppIcon.icns"
if [ ! -f "$ICON_SRC" ]; then
    echo "▸ AppIcon.icns missing, generating…"
    "$ROOT/Scripts/build-icon.sh"
fi

APP_DIR="$ROOT/dist/$APP_NAME.app"
echo "▸ Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$EXEC" "$APP_DIR/Contents/MacOS/PivSigner"
cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT/PrivacyInfo.xcprivacy" "$APP_DIR/Contents/Resources/PrivacyInfo.xcprivacy"

# Bundled SwiftPM resources (Localizable.strings, etc.)
MODULE_BUNDLE="$BIN_PATH/PivSigner_PivSigner.bundle"
if [ -d "$MODULE_BUNDLE" ]; then
    cp -R "$MODULE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PivSigner</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 FieldHub Inc. Apache 2.0.</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
        <string>uk</string>
    </array>
</dict>
</plist>
EOF

touch "$APP_DIR"

# Optional code signing
if [ -n "${SIGN_IDENTITY:-}" ]; then
    ENTITLEMENTS="$ROOT/PivSigner.entitlements"
    [ -f "$ENTITLEMENTS" ] || { echo "Missing $ENTITLEMENTS"; exit 1; }

    echo "▸ Signing with: $SIGN_IDENTITY"

    # Sign nested resource bundles first (no entitlements, no hardened runtime
    # is required for resource-only bundles, but we do it for verify --deep)
    if [ -d "$APP_DIR/Contents/Resources/PivSigner_PivSigner.bundle" ]; then
        codesign --force --options runtime --timestamp \
            --sign "$SIGN_IDENTITY" \
            "$APP_DIR/Contents/Resources/PivSigner_PivSigner.bundle"
    fi

    # Sign the main executable
    codesign --force --options runtime --timestamp \
        --sign "$SIGN_IDENTITY" \
        "$APP_DIR/Contents/MacOS/PivSigner"

    # Sign the bundle with entitlements
    codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" \
        "$APP_DIR"

    echo "▸ Verifying signature…"
    codesign --verify --deep --strict --verbose=2 "$APP_DIR"
    echo "✓ Signed"
fi

echo "✓ Built $APP_DIR"
echo "  Open with: open '$APP_DIR'"
