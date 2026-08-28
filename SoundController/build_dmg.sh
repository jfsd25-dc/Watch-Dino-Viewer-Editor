#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP_NAME="Sound Controller"
APP="$BUILD/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
DMG="$BUILD/Sound-Controller.dmg"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$BUILD"
mkdir -p "$MACOS" "$RESOURCES" "$BUILD/arch" "$BUILD/dmg-root"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>Sound Controller</string>
  <key>CFBundleExecutable</key><string>SoundController</string>
  <key>CFBundleIdentifier</key><string>app.dino.soundcontroller</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Sound Controller</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

for ARCH in arm64 x86_64; do
  xcrun --sdk macosx swiftc \
    -parse-as-library \
    -target "${ARCH}-apple-macos13.0" \
    -sdk "$SDK" \
    -O \
    "$ROOT/SoundController.swift" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Combine \
    -o "$BUILD/arch/SoundController-$ARCH"
done

lipo -create \
  "$BUILD/arch/SoundController-arm64" \
  "$BUILD/arch/SoundController-x86_64" \
  -output "$MACOS/SoundController"
chmod +x "$MACOS/SoundController"

cat > "$BUILD/make_icon.swift" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedWhite: 0.015, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 220, yRadius: 220).fill()

NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 160, y: 190, width: 704, height: 644), xRadius: 120, yRadius: 120).fill()

let speaker = NSBezierPath()
speaker.move(to: NSPoint(x: 270, y: 430))
speaker.line(to: NSPoint(x: 390, y: 430))
speaker.line(to: NSPoint(x: 555, y: 305))
speaker.line(to: NSPoint(x: 555, y: 719))
speaker.line(to: NSPoint(x: 390, y: 594))
speaker.line(to: NSPoint(x: 270, y: 594))
speaker.close()
NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
speaker.fill()

NSColor(calibratedWhite: 0.96, alpha: 0.9).setStroke()
for inset in [0.0, 75.0] {
    let arc = NSBezierPath()
    arc.lineWidth = 34
    arc.appendArc(withCenter: NSPoint(x: 555, y: 512), radius: 145 + inset, startAngle: -52, endAngle: 52, clockwise: false)
    arc.stroke()
}

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

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

cp -R "$APP" "$BUILD/dmg-root/"
ln -s /Applications "$BUILD/dmg-root/Applications"
cat > "$BUILD/dmg-root/README.txt" <<'TXT'
Sound Controller for macOS

1. Drag “Sound Controller” to Applications.
2. Open it from Applications.
3. If macOS blocks this personal, non-notarized build on first launch: Control-click the app → Open → Open.

Controls
• Speaker Output: drag the slider, then release to apply.
• 25 / 50 / 75 / 100%: quick speaker presets.
• − / +: speaker volume by 5%.
• Mute / Unmute: controls Mac output mute.
• Microphone Input: controls Mac input gain where supported by the active input device.
• Alert Volume: controls macOS alert/system-sound volume.
• Test: plays the Mac alert sound.
• Keep on top: keeps the controller floating above normal windows.
• Refresh: syncs the panel with current macOS volume settings.

Some external USB/Bluetooth devices expose fixed volume or input gain, so macOS may ignore a slider for those devices.
TXT

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$BUILD/dmg-root" \
  -ov \
  -format UDZO \
  "$DMG"

shasum -a 256 "$DMG" | tee "$BUILD/Sound-Controller.sha256"
file "$MACOS/SoundController"
ls -lh "$DMG"
echo "Built: $DMG"
