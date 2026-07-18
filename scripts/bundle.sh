#!/bin/bash
# Builds LockedIn.app — a release SwiftPM binary wrapped in a proper .app bundle
# so it can run as a menu-bar agent (LSUIElement) with an Info.plist.
#
# Signing:
#   default            → ad-hoc (local dev; Gatekeeper needs right-click → Open)
#   SIGN_IDENTITY=...  → Developer ID signing with hardened runtime + timestamp
#                        (required for notarization — see scripts/release.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="LockedIn"
BUNDLE="build/$APP.app"
VERSION="$(cat VERSION 2>/dev/null || echo 0.1)"
BUILD_NUM="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

echo "Building release binary (v$VERSION build $BUILD_NUM)..."
swift build -c release

echo "Assembling $BUNDLE ..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/$APP" "$BUNDLE/Contents/MacOS/$APP"

# App icon (generate with scripts/make_icon.py; committed to Resources/).
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Privacy manifest — declares required-reason API usage (Apple requirement).
if [ -f "Resources/PrivacyInfo.xcprivacy" ]; then
  cp "Resources/PrivacyInfo.xcprivacy" "$BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
fi

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundleDisplayName</key><string>LockedIn</string>
  <key>CFBundleIdentifier</key><string>com.lockedin.app</string>
  <key>CFBundleVersion</key><string>$BUILD_NUM</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Pavel Tarasov. MIT License.</string>
  <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST

if [ -n "${SIGN_IDENTITY:-}" ]; then
  # Developer ID: hardened runtime + secure timestamp + entitlements (notarization-ready).
  echo "Signing with Developer ID: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp \
    --entitlements "Resources/LockedIn.entitlements" \
    --sign "$SIGN_IDENTITY" "$BUNDLE"
  codesign --verify --strict --verbose=2 "$BUNDLE"
else
  # Ad-hoc sign so macOS will run it locally without quarantine grief.
  codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true
fi

echo "Built $BUNDLE"
