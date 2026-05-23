#!/bin/bash
set -e

echo "Building ClipHistory..."
cd "$(dirname "$0")"

# Kill running instance before building
pkill -f "ClipHistory.app/Contents/MacOS/ClipHistory" 2>/dev/null || true

# Build with Xcode
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project ClipHistory.xcodeproj \
    -scheme ClipHistory \
    -configuration Release \
    build 2>&1 | grep -E "(error:|warning:|BUILD|Compiling)" | grep -v "note:"

echo ""

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ClipHistory-*/Build/Products/Release -name "ClipHistory.app" -maxdepth 1 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "ERROR: Could not find built app"
    exit 1
fi

echo "Installing to /Applications..."
cp -R "$APP_PATH" /Applications/

echo ""
echo "Done! ClipHistory is now in /Applications and Launchpad."
echo "Starting app..."
open /Applications/ClipHistory.app
