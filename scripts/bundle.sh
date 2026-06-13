#!/bin/bash
# Builds LockedIn.app — a release SwiftPM binary wrapped in a proper .app bundle
# so it can run as a menu-bar agent (LSUIElement) with an Info.plist.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="LockedIn"
BUNDLE="build/$APP.app"

echo "Building release binary..."
swift build -c release

echo "Assembling $BUNDLE ..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/$APP" "$BUNDLE/Contents/MacOS/$APP"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundleDisplayName</key><string>LockedIn</string>
  <key>CFBundleIdentifier</key><string>com.lockedin.app</string>
  <key>CFBundleVersion</key><string>0.1</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Stage 1 prototype</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS will run it locally without quarantine grief.
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "Built $BUNDLE"
