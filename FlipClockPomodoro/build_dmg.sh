#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP_NAME="FlipClock Pomodoro"
APP="$BUILD/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
DMG="$BUILD/FlipClock-Pomodoro.dmg"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$BUILD"
mkdir -p "$MACOS" "$RESOURCES" "$BUILD/arch" "$BUILD/dmg-root"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>FlipClock Pomodoro</string>
  <key>CFBundleExecutable</key><string>FlipClockPomodoro</string>
  <key>CFBundleIdentifier</key><string>app.dino.flipclockpomodoro</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>FlipClock Pomodoro</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

# Build both Apple Silicon and Intel binaries, then combine into one universal executable.
for ARCH in arm64 x86_64; do
  xcrun --sdk macosx swiftc \
    -parse-as-library \
    -target "${ARCH}-apple-macos13.0" \
    -sdk "$SDK" \
    -O \
    "$ROOT/FlipClockPomodoro.swift" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Combine \
    -o "$BUILD/arch/FlipClockPomodoro-$ARCH"
done

lipo -create \
  "$BUILD/arch/FlipClockPomodoro-arm64" \
  "$BUILD/arch/FlipClockPomodoro-x86_64" \
  -output "$MACOS/FlipClockPomodoro"
chmod +x "$MACOS/FlipClockPomodoro"

# Generate a clean native app icon without external dependencies.
cat > "$BUILD/make_icon.swift" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedWhite: 0.015, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 220, yRadius: 220).fill()

let panelColor = NSColor(calibratedWhite: 0.07, alpha: 1)
panelColor.setFill()
NSBezierPath(roundedRect: NSRect(x: 130, y: 245, width: 764, height: 535), xRadius: 70, yRadius: 70).fill()

NSColor(calibratedWhite: 0.01, alpha: 0.95).setFill()
NSBezierPath(rect: NSRect(x: 130, y: 510, width: 764, height: 3)).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 330, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.94, alpha: 1),
    .paragraphStyle: paragraph
]
("25" as NSString).draw(in: NSRect(x: 130, y: 310, width: 764, height: 390), withAttributes: attrs)

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("Unable to create icon") }
try png.write(to: URL(fileURLWithPath: output))
SWIFT

xcrun swift "$BUILD/make_icon.swift" "$BUILD/icon-1024.png"
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
for SPEC in "16 16" "16 32" "32 32" "32 64" "128 128" "128 256" "256 256" "256 512" "512 512" "512 1024"; do
  set -- $SPEC
  LOGICAL="$1"; PIXELS="$2"
  if [ "$LOGICAL" = "$PIXELS" ]; then
    NAME="icon_${LOGICAL}x${LOGICAL}.png"
  else
    NAME="icon_${LOGICAL}x${LOGICAL}@2x.png"
  fi
  sips -z "$PIXELS" "$PIXELS" "$BUILD/icon-1024.png" --out "$ICONSET/$NAME" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

# Ad-hoc signing keeps the app internally consistent. A Developer ID is needed for notarization.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# Create a familiar drag-to-Applications DMG.
cp -R "$APP" "$BUILD/dmg-root/"
ln -s /Applications "$BUILD/dmg-root/Applications"
cat > "$BUILD/dmg-root/README.txt" <<'TXT'
FlipClock Pomodoro 1.1

1. Drag “FlipClock Pomodoro” to Applications.
2. Open it from Applications.
3. If macOS blocks the first launch because this personal build is not notarized, Control-click the app, choose Open, then choose Open again.

Clock
• Shows HOUR : MIN : SEC.
• Switch between 12-hour and 24-hour time.

Timer
• Choose Count Down or Count Up.
• Both modes show HOUR : MIN : SEC, up to 99:59:59.
• Before starting, place the pointer over HOUR, MIN, or SEC and scroll up/down with a mouse wheel or trackpad to change that value.
• Small up/down buttons below each value provide a non-scroll alternative.
• Count Down remembers its own starting value.
• Count Up remembers its own starting value and can begin from 00:00:00 or another value.
• Space starts/pauses; Reset returns to the saved starting value.

Pomodoro
• Focus 25 min • Short Break 5 min • Long Break 15 min by default.
• − / + changes the selected Pomodoro phase by one minute.
• Space starts/pauses and Reset restores the selected phase.

Display
• Double-click the clock or use the fullscreen button to toggle fullscreen.
• Controls fade down automatically to keep the display clean.
TXT

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$BUILD/dmg-root" \
  -ov \
  -format UDZO \
  "$DMG"

shasum -a 256 "$DMG" | tee "$BUILD/FlipClock-Pomodoro.sha256"
file "$MACOS/FlipClockPomodoro"
ls -lh "$DMG"

echo "Built: $DMG"
