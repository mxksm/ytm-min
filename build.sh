#!/bin/bash

APP_NAME="ytm-min"
APP_DIR="$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "Cleaning..."
rm -rf "$APP_DIR"

echo "Compiling..."
swiftc App.swift ContentView.swift YTMusicBridge.swift -o "$APP_NAME"

if [ $? -eq 0 ]; then
    mkdir -p "$BIN_DIR"
    mkdir -p "$RESOURCES_DIR"
    mv "$APP_NAME" "$BIN_DIR/"

    # App Icon Generation Logic
    ICON_XML=""
    if [ -f "icon.png" ]; then
        echo "🎨 Compiling AppIcon.icns..."
        mkdir -p icon.iconset
        sips -z 16 16     icon.png --out icon.iconset/icon_16x16.png &> /dev/null
        sips -z 32 32     icon.png --out icon.iconset/icon_16x16@2x.png &> /dev/null
        sips -z 32 32     icon.png --out icon.iconset/icon_32x32.png &> /dev/null
        sips -z 64 64     icon.png --out icon.iconset/icon_32x32@2x.png &> /dev/null
        sips -z 128 128   icon.png --out icon.iconset/icon_128x128.png &> /dev/null
        sips -z 256 256   icon.png --out icon.iconset/icon_128x128@2x.png &> /dev/null
        sips -z 256 256   icon.png --out icon.iconset/icon_256x256.png &> /dev/null
        sips -z 512 512   icon.png --out icon.iconset/icon_256x256@2x.png &> /dev/null
        sips -z 512 512   icon.png --out icon.iconset/icon_512x512.png &> /dev/null
        sips -z 1024 1024 icon.png --out icon.iconset/icon_512x512@2x.png &> /dev/null
        
        iconutil -c icns icon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
        rm -rf icon.iconset
        ICON_XML="<key>CFBundleIconFile</key><string>AppIcon</string>"
    fi

    cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.$APP_NAME.v3</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    $ICON_XML
</dict>
</plist>
EOF
    echo "Installing to /Applications..."
    pkill -x "$APP_NAME" &> /dev/null || true
    rm -rf "/Applications/$APP_DIR"
    ditto "$APP_DIR" "/Applications/$APP_DIR"

    echo "Refreshing macOS icon cache..."
    touch "/Applications/$APP_DIR"
    /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "/Applications/$APP_DIR"
    killall Dock

    echo "Done!"
    open "/Applications/$APP_DIR"
else
    echo "Failed."
    exit 1
fi
