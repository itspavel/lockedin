#!/bin/bash
# Builds LockedIn.app and packages it into a draggable LockedIn.dmg.
# No Xcode required. For distribution to OTHER Macs without Gatekeeper warnings,
# the .app must be Developer-ID signed + notarized first (see scripts/sign.sh, TODO).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh

STAGING=$(mktemp -d)
cp -R build/LockedIn.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"     # drag-to-install target

rm -f build/LockedIn.dmg
hdiutil create -volname "LockedIn" \
  -srcfolder "$STAGING" -ov -format UDZO \
  build/LockedIn.dmg >/dev/null
rm -rf "$STAGING"

echo "Built build/LockedIn.dmg"
