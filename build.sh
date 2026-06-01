#!/bin/bash
APP_NAME="ytm-min"
APP_DIR="$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"

echo "Cleaning..."
rm -rf "$APP_DIR"

echo "Compiling..."
swiftc App.swift ContentView.swift YTMusicBridge.swift -o "$APP_NAME"

if [ $? -eq 0 ]; then
    mkdir -p "$BIN_DIR"
    mv "$APP_NAME" "$BIN_DIR/"
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
</dict>
</plist>
EOF
    echo "Installing to /Applications..."
    sudo rm -rf /Applications/"$APP_DIR"
    sudo mv "$APP_DIR" /Applications/
    echo "Done!"
else
    echo "Failed."
    exit 1
fi
