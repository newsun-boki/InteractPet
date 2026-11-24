#!/bin/zsh
set -eu
cd "${0:A:h}"
APP="${TARO_APP_OUTPUT:-../../output/octopus-pet/Taro Octopus.app}"
CACHE="${TARO_MODULE_CACHE:-../../.cache/swift}"
CACHE="${CACHE:A}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE"
xcrun swiftc -O -module-cache-path "$CACHE" Sources/*.swift -o "$APP/Contents/MacOS/TaroOctopus" -framework AppKit -framework ApplicationServices -framework Carbon
cp Assets/mantle.png "$APP/Contents/Resources/mantle.png"
mkdir -p "$APP/Contents/Resources/Skins"
cp Assets/Skins/skins.json Assets/Skins/*.png "$APP/Contents/Resources/Skins/"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier local.tarooctopus.pet "$APP"
echo "$APP"
