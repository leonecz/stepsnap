#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="build/StepSnap.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/StepSnap" "$APP/Contents/MacOS/StepSnap"
cp "packaging/Info.plist" "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"

echo "Готово: $APP"
