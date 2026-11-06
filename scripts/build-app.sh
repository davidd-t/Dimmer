#!/bin/bash
# Builds Dimmer.app. Pass --install to also put it in /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/Dimmer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Dimmer "$APP/Contents/MacOS/Dimmer"
cp App/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    osascript -e 'tell application id "local.dimmer" to quit' 2>/dev/null || true
    rm -rf /Applications/Dimmer.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/Dimmer.app"
fi
