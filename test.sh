#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

PROJECT="ClipHistory.xcodeproj"
SCHEME="ClipHistory"
TMP_ROOT="${TMPDIR:-/tmp}"
DERIVED_DATA="${TMP_ROOT%/}/cliphistory-derived-data"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/ClipHistory.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
if [ ! -x "$XCODEBUILD" ]; then
    XCODEBUILD="$(command -v xcodebuild || true)"
fi
if [ -z "$XCODEBUILD" ] || [ ! -x "$XCODEBUILD" ]; then
    echo "ERROR: xcodebuild not found. Install Xcode and try again." >&2
    exit 1
fi

cleanup() {
    # Xcode registers every built .app with LaunchServices, which would
    # otherwise show up as another ClipHistory in Spotlight.
    "$LSREGISTER" -u "$APP_PATH" >/dev/null 2>&1 || true
    rm -rf "$APP_PATH"
}
trap cleanup EXIT

if [ ! -d "$PROJECT" ]; then
    echo "ERROR: $PROJECT not found. Run 'xcodegen generate' first." >&2
    exit 1
fi

"$XCODEBUILD" \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'platform=macOS' \
    test
