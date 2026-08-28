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

# Create an icon locally so the project has no binary source dependencies.
cat > "$BUILD/make_icon.swift" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedRed: 0.025, green: 0.025, blue: 0.03, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 220, yRadius: 220).fill()

NSColor(calibratedWhite: 1, alpha: 0.08).setFill()
NSBezierPath(roundedRect: NSRect(x: 148, y: 170, width: 728, height: 684), xRadius: 92, yRadius: 92).fill()

let centered = NSMutableParagraphStyle()
centered.alignment = .center

let aele: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 130, weight: .bold),
    .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1),
    .paragraphStyle: centered,
    .kern: 12
]
("AELE" as NSString).draw(in: NSRect(x: 150, y: 590, width: 724, height: 170), withAttributes: aele)

let digits: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 300, weight: .black),
    .foregroundColor: NSColor(calibratedWhite: 0.98, alpha: 1),
    .paragraphStyle: centered
]
("26" as NSString).draw(in: NSRect(x: 150, y: 260, width: 724, height: 350), withAttributes: digits)

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Unable to create icon")
}
try png.write(to: URL(fileURLWithPath: output))
SWIFT

xcrun swift "$BUILD/make_icon.swift" "$BUILD/icon-1024.png"
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
for SPEC in "16 16" "16 32" "32 32" "32 64" "128 128" "128 256" "256 256" "256 512" "512 512" "512 1024"; do
  set -- $SPEC
  LOGICAL="$1"
  PIXELS="$2"
  if [ "$LOGICAL" = "$PIXELS" ]; then
    NAME="icon_${LOGICAL}x${LOGICAL}.png"
  else
    NAME="icon_${LOGICAL}x${LOGICAL}@2x.png"
  fi
  sips -z "$PIXELS" "$PIXELS" "$BUILD/icon-1024.png" --out "$ICONSET/$NAME" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"

# Ad-hoc sign the extension first, then the containing app.
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
