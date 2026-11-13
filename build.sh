#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
    ""|--install) ;;
    *) echo "Usage: $0 [--install]" >&2; exit 2 ;;
esac

APP_NAME="ytm-min"
APP_DIR="$APP_NAME.app"
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/ytm-min-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
BUNDLE="$STAGING/$APP_DIR"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
echo "Compiling..."
swiftc -O -module-cache-path "${TMPDIR:-/tmp}/ytm-min-module-cache" \
    App.swift ContentView.swift YTMusicBridge.swift KeyboardShortcuts.swift \
    -o "$BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/player.js "$BUNDLE/Contents/Resources/"

ICON_XML=""
if [ -f icon.png ]; then
    ICONSET="$STAGING/icon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        doubled=$((size * 2))
        sips -z "$doubled" "$doubled" icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns"
    ICON_XML='<key>CFBundleIconFile</key><string>AppIcon</string>'
fi
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>com.local.$APP_NAME.v3</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1</string>
    <key>CFBundleVersion</key><string>2</string>
    $ICON_XML
</dict></plist>
PLIST
codesign --force --sign - "$BUNDLE"
# Keep the previous build intact until compilation and packaging have succeeded.
rm -rf "$APP_DIR"
mv "$BUNDLE" "$APP_DIR"
echo "Built $PWD/$APP_DIR"
if [ "${1:-}" = --install ]; then
    pkill -x "$APP_NAME" || true
    ditto "$APP_DIR" "/Applications/$APP_DIR"
    open "/Applications/$APP_DIR"
fi
