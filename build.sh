#!/bin/bash

APP_NAME="MixletClone"
APP_DIR="$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"

echo "Cleaning old builds..."
rm -rf "$APP_DIR"

echo "Compiling Swift files..."
# This uses swiftc to compile the 3 files into a single binary
swiftc App.swift ContentView.swift YTMusicBridge.swift -o "$APP_NAME"

# Check if compilation succeeded
if [ $? -eq 0 ]; then
    echo "Compilation successful. Packaging into $APP_DIR..."
    
    # Create the standard macOS app bundle structure
    mkdir -p "$BIN_DIR"
    mv "$APP_NAME" "$BIN_DIR/"
    
    # Create a minimal Info.plist so macOS knows how to launch it
    cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

    echo "Installing to ~/Applications..."
    mkdir -p ~/Applications
    rm -rf ~/Applications/"$APP_DIR"
    mv "$APP_DIR" ~/Applications/
    
    echo "Done! Launching..."
    open ~/Applications/"$APP_DIR"
else
    echo "Compilation failed."
    exit 1
fi
