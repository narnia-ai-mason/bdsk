#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Config/Info.plist)"
fi

DEST="$ROOT/dist"
APP="$ROOT/build/Build/Products/Release/bdsk.app"
STAGE="$DEST/dmg-root"
RW="$DEST/bdsk-rw.dmg"
DMG="$DEST/bdsk-${VERSION}-macos.dmg"

mkdir -p "$DEST"

xcodebuild \
  -project bdsk.xcodeproj \
  -scheme bdsk \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  build

rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/bdsk.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$RW" "$DMG"
hdiutil create \
  -volname "bdsk" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  "$RW" >/dev/null

MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk '/\/Volumes\// { print $3 }')"
if [ -n "$MOUNT" ]; then
  osascript <<EOF >/dev/null
tell application "Finder"
  tell disk "bdsk"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {220, 140, 780, 500}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 96
    set position of item "bdsk.app" of container window to {160, 180}
    set position of item "Applications" of container window to {400, 180}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF
  hdiutil detach "$MOUNT" >/dev/null
fi

hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"
rm -rf "$STAGE"
shasum -a 256 "$DMG" | tee "$DMG.sha256"

echo "$DMG"
