#!/bin/bash
# Regenerate AppIcon.icns from Tools/MakeIcon.swift.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
swift "$ROOT/Tools/MakeIcon.swift" "$ICONSET"
mkdir -p "$ROOT/Sources/PivSigner/Resources"
iconutil -c icns "$ICONSET" -o "$ROOT/Sources/PivSigner/Resources/AppIcon.icns"
cp "$ICONSET/icon_256x256@2x.png" "$ROOT/Sources/PivSigner/Resources/AppIcon.png"
echo "✓ Wrote Sources/PivSigner/Resources/AppIcon.icns"
echo "✓ Wrote Sources/PivSigner/Resources/AppIcon.png"
