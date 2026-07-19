#!/bin/bash
# Full release pipeline: Developer ID sign → DMG → notarize → staple → verify.
#
# Prereqs (one-time):
#   1. Apple Developer Program membership ($99/yr).
#   2. A "Developer ID Application" certificate in your keychain
#      (Xcode → Settings → Accounts → Manage Certificates, or developer.apple.com).
#   3. An app-specific password for notarytool: appleid.apple.com → App-Specific Passwords.
#   4. Store credentials once:
#        xcrun notarytool store-credentials lockedin \
#          --apple-id "you@example.com" --team-id "TEAMID1234" --password "app-specific-pw"
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID1234)" ./scripts/release.sh
#
# Without SIGN_IDENTITY this prints the checklist and exits — it never ships ad-hoc builds.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION 2>/dev/null || echo 0.1)"
DMG="build/LockedIn-$VERSION.dmg"
PROFILE="${NOTARY_PROFILE:-lockedin}"

if [ -z "${SIGN_IDENTITY:-}" ]; then
  echo "SIGN_IDENTITY is not set — refusing to release an ad-hoc build."
  echo
  echo "  SIGN_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\" ./scripts/release.sh"
  echo
  echo "See docs/RELEASE.md for the full checklist (certificate, notarytool credentials)."
  exit 1
fi

echo "==> 1/5 Build + sign (hardened runtime, timestamp)"
SIGN_IDENTITY="$SIGN_IDENTITY" ./scripts/bundle.sh

echo "==> 2/5 Build DMG"
rm -f "$DMG"
hdiutil create -volname "LockedIn" -srcfolder build/dmg-staging -ov -format UDZO "$DMG" 2>/dev/null || {
  # Fall back to the standard staging layout used by scripts/dmg.sh
  STAGE="build/dmg-staging"
  rm -rf "$STAGE"; mkdir -p "$STAGE"
  cp -R "build/LockedIn.app" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "LockedIn" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
}
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "==> 3/5 Notarize (waits for Apple)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> 4/5 Staple the ticket"
xcrun stapler staple "$DMG"
xcrun stapler staple "build/LockedIn.app" || true

echo "==> 5/5 Verify Gatekeeper acceptance"
spctl --assess --type open --context context:primary-signature -v "$DMG"
shasum -a 256 "$DMG"

echo
echo "Done: $DMG is notarized + stapled."
echo "Ship it: cp to ../lockedin-site/public/download/LockedIn.dmg, bump its appcast.json"
echo "(version + notes), then deploy the site. In-app updaters will pick it up."
