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

eject_bdsk_volumes() {
  for path in /Volumes/bdsk /Volumes/bdsk\ *; do
    if [ -e "$path" ]; then
      hdiutil detach "$path" -force >/dev/null || true
    fi
  done
}

wait_for_file() {
  file="$1"
  tries=0
  while [ ! -f "$file" ] && [ "$tries" -lt 30 ]; do
    sleep 0.2
    tries=$((tries + 1))
  done
  [ -f "$file" ]
}

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

eject_bdsk_volumes
rm -f "$RW" "$DMG"
hdiutil create \
  -volname "bdsk" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  "$RW" >/dev/null

ATTACH="$(hdiutil attach -readwrite -noverify -noautoopen "$RW")"
MOUNT="$(printf '%s\n' "$ATTACH" | sed -n 's/.*\(\/Volumes\/.*\)$/\1/p' | tail -1)"
if [ -z "$MOUNT" ] || [ ! -d "$MOUNT" ]; then
  echo "failed to mount $RW" >&2
  exit 1
fi
VOLNAME="$(basename "$MOUNT")"

osascript - "$VOLNAME" <<'EOF'
on run argv
  set volName to item 1 of argv
  tell application "Finder"
    tell disk volName
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
      delay 2
      close
    end tell
  end tell
end run
EOF

if ! wait_for_file "$MOUNT/.DS_Store"; then
  echo "Finder did not write window layout to $MOUNT/.DS_Store" >&2
  hdiutil detach "$MOUNT" -force >/dev/null || true
  exit 1
fi

sync
sleep 1
hdiutil detach "$MOUNT" >/dev/null || hdiutil detach "$MOUNT" -force >/dev/null
sleep 1

hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"
rm -rf "$STAGE"
shasum -a 256 "$DMG" | tee "$DMG.sha256"

echo "$DMG"
