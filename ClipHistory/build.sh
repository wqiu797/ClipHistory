#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

PROJECT="ClipHistory.xcodeproj"
SCHEME="ClipHistory"
CONFIGURATION="Release"
DERIVED_DATA="$PWD/build"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/ClipHistory.app"
INSTALL_PATH="/Applications/ClipHistory.app"
LOG_FILE="$DERIVED_DATA/build.log"

if [ ! -d "$PROJECT" ]; then
    echo "ERROR: $PROJECT not found. Run 'xcodegen generate' first." >&2
    exit 1
fi

XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
if [ ! -x "$XCODEBUILD" ]; then
    XCODEBUILD="$(command -v xcodebuild || true)"
fi
if [ -z "$XCODEBUILD" ] || [ ! -x "$XCODEBUILD" ]; then
    echo "ERROR: xcodebuild not found. Install Xcode and try again." >&2
    exit 1
fi

mkdir -p "$DERIVED_DATA"

echo "Building ClipHistory ($CONFIGURATION)..."
if ! "$XCODEBUILD" \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    build > "$LOG_FILE" 2>&1
then
    echo "" >&2
    echo "ERROR: Build failed. Last 40 lines of $LOG_FILE:" >&2
    tail -40 "$LOG_FILE" >&2
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build succeeded but $APP_PATH is missing." >&2
    exit 1
fi

# Only touch the running app once a fresh build exists.
echo "Stopping any running ClipHistory instance..."
pkill -f "ClipHistory.app/Contents/MacOS/ClipHistory" 2>/dev/null || true

echo "Installing to /Applications..."
rm -rf "$INSTALL_PATH"
ditto "$APP_PATH" "$INSTALL_PATH"

echo ""
echo "Done! ClipHistory is now in /Applications and Launchpad."
echo "Starting app..."
open "$INSTALL_PATH"
