#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="build/StepSnap.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/StepSnap" "$APP/Contents/MacOS/StepSnap"
cp "packaging/Info.plist" "$APP/Contents/Info.plist"

# Подпись берём из связки ключей, если она там есть: при ad-hoc подписи хеш бинарника
# меняется на каждой пересборке, и macOS считает приложение новым, требуя заново выдать
# разрешение на запись экрана. С сертификатом подпись стабильна и разрешение живёт.
SIGN_IDENTITY="${STEPSNAP_SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)".*/\1/p' | head -1)
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "Подпись: $SIGN_IDENTITY"
    codesign --force --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
else
    echo "Подпись: ad-hoc (сертификата в связке ключей нет — после каждой сборки разрешение придётся выдавать заново)"
    codesign --force --sign - "$APP"
fi

echo "Готово: $APP"
