#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build-aele-widget"
DERIVED="$BUILD/DerivedData"
APP="$DERIVED/Build/Products/Release/AELE Countdown.app"
WIDGET="$APP/Contents/PlugIns/AELECountdownWidget.appex"
DMG="$BUILD/AELE-Countdown-Widget.dmg"

rm -rf "$BUILD"
mkdir -p "$BUILD"

xcodebuild \
  -project "$ROOT/AELECountdown.xcodeproj" \
  -scheme "AELE Countdown" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  build

test -d "$APP"
test -d "$WIDGET"

# Ad-hoc sign the WidgetKit extension first, then the containing app.
codesign --force --sign - \
  --entitlements "$ROOT/AELECountdownWidget/AELECountdownWidget.entitlements" \
  "$WIDGET"

codesign --force --sign - \
  --entitlements "$ROOT/AELECountdown/AELECountdown.entitlements" \
  "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

# Confirm both architectures made it into the host and widget executables.
file "$APP/Contents/MacOS/AELE Countdown"
file "$WIDGET/Contents/MacOS/AELECountdownWidget"
lipo -info "$APP/Contents/MacOS/AELE Countdown"
lipo -info "$WIDGET/Contents/MacOS/AELECountdownWidget"

STAGE="$BUILD/dmg-root"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/README.txt" <<'TXT'
AELE Countdown Widget
Target: November 9, 2026 — Day 1 of the Aeronautical Engineer Licensure Exam

INSTALL
1. Drag “AELE Countdown” to Applications.
2. Open AELE Countdown once.
3. If macOS blocks this personal build, Control-click the app → Open → Open.
4. Right-click the desktop → Edit Widgets.
5. Search “AELE Countdown”.
6. Drag the Small, Medium, or Large widget onto the desktop.

The widget updates automatically each day.
Requires macOS 14 Sonoma or newer for desktop widgets.
TXT

hdiutil create \
  -volname "AELE Countdown" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

hdiutil verify "$DMG"
shasum -a 256 "$DMG" | tee "$BUILD/AELE-Countdown-Widget.sha256"
ls -lh "$DMG"
echo "Built: $DMG"
