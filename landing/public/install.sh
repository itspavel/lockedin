#!/bin/sh
# LockedIn installer — https://github.com/itspavel/lockedin
# Fetches the latest DMG from GitHub Releases and installs it to /Applications.
# curl-downloaded files carry no quarantine flag, so first launch just works.
set -eu

REPO="itspavel/lockedin"
URL="https://github.com/$REPO/releases/latest/download/LockedIn.dmg"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

[ "$(uname)" = "Darwin" ] || { echo "LockedIn is macOS-only."; exit 1; }

printf '$ downloading LockedIn (latest release) ...\n'
curl -fSL --progress-bar "$URL" -o "$TMP/LockedIn.dmg"

printf '$ installing to /Applications ...\n'
MOUNT=$(hdiutil attach -nobrowse -readonly "$TMP/LockedIn.dmg" | awk -F'\t' '/\/Volumes\//{print $NF; exit}')
[ -d "$MOUNT/LockedIn.app" ] || { echo "unexpected DMG layout — aborting."; exit 1; }
pkill -x LockedIn 2>/dev/null || true
rm -rf /Applications/LockedIn.app
ditto "$MOUNT/LockedIn.app" /Applications/LockedIn.app
hdiutil detach "$MOUNT" -quiet
xattr -dr com.apple.quarantine /Applications/LockedIn.app 2>/dev/null || true

open /Applications/LockedIn.app
printf '$ done — look up: LockedIn lives in your menu bar.\n'
