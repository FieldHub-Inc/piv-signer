#!/bin/bash
# Build PIV Signer.app bundle from the Swift package binary.
# Usage: ./Scripts/build-app.sh [release|debug]   (default: release)

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

# Bundled SwiftPM resources (Localizable.strings, etc.) — copy module bundle if present
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
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 FieldHub Inc. Apache 2.0.</string>
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

# refresh icon cache so Finder picks up the new icon immediately
touch "$APP_DIR"

echo "✓ Built $APP_DIR"
echo "  Open with: open '$APP_DIR'"
