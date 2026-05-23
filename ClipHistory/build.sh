#!/bin/bash
set -e

echo "Building ClipHistory..."
cd "$(dirname "$0")"

# Build with Xcode
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project ClipHistory.xcodeproj \
    -scheme ClipHistory \
    -configuration Release \
    build 2>&1 | grep -E "(error:|warning:|BUILD|Compiling)" | grep -v "note:"

echo ""
echo "Build complete!"
echo ""

# Find and show the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ClipHistory-*/Build/Products/Release -name "ClipHistory.app" -maxdepth 1 2>/dev/null | head -1)

if [ -n "$APP_PATH" ]; then
    echo "App built at: $APP_PATH"
    echo ""
    echo "To install to /Applications:"
    echo "  cp -R \"$APP_PATH\" /Applications/"
    echo ""
    echo "To run directly:"
    echo "  open \"$APP_PATH\""
else
    echo "App built successfully (check DerivedData for .app)"
fi
