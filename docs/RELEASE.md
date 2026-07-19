# Releasing LockedIn — Apple distribution checklist

LockedIn ships as a **notarized Developer ID app** (direct download), not through the
Mac App Store. That's deliberate: the App Store's mandatory sandbox forbids the app's
core function — reading Claude Code's local logs (`~/.claude/projects`) and running
`git` for repo stats. Notarization + hardened runtime is Apple's supported path for
apps like this ([Signing Mac Software with Developer ID](https://developer.apple.com/developer-id/)).

## One-time setup

1. **Apple Developer Program** — enroll at developer.apple.com ($99/yr).
2. **Developer ID Application certificate** — Xcode → Settings → Accounts →
   Manage Certificates → “+” → Developer ID Application. Must be this exact type —
   a regular “Apple Development” cert cannot notarize.
3. **App-specific password** — appleid.apple.com → Sign-In & Security → App-Specific
   Passwords (notarytool cannot use your normal password).
4. **Store notary credentials** (once):
   ```sh
   xcrun notarytool store-credentials lockedin \
     --apple-id "you@example.com" --team-id "TEAMID1234" --password "xxxx-xxxx-xxxx-xxxx"
   ```

## Every release

```sh
# 1. bump the version + release notes
echo "0.2" > VERSION
$EDITOR ../lockedin-site/public/appcast.json     # version, date, notes[] — feeds in-app updates
$EDITOR ../lockedin-site/src/app/changelog/page.tsx

# 2. sign, notarize, staple, verify (all in one)
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh

# 3. publish
cp build/LockedIn-0.2.dmg ../lockedin-site/public/download/LockedIn.dmg
cd ../lockedin-site && npx vercel deploy --prod --yes   # commit + push that repo too
```

Users on older versions see the in-app **“Update available”** banner + notification
(the app polls `appcast.json` every few hours) with your release notes.

## What the pipeline enforces (and why Apple requires it)

| Step | Why |
|---|---|
| `--options runtime` (hardened runtime) | Required for notarization; blocks code injection ([Apple: Resolving common notarization issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)) |
| `--timestamp` | Secure timestamps are mandatory for notarized code |
| `Resources/LockedIn.entitlements` | Empty on purpose — we need no hardened-runtime exceptions |
| `Resources/PrivacyInfo.xcprivacy` | Privacy manifest declaring required-reason API use (UserDefaults, file timestamps) |
| `notarytool submit --wait` | Apple scans for malware; required for Gatekeeper to pass the app outside the App Store ([Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)) |
| `stapler staple` | Attaches the ticket so the app verifies offline |
| `spctl --assess` | Final Gatekeeper simulation before shipping |

## Gatekeeper before/after

- **Now (ad-hoc):** users must right-click → Open on first launch, and macOS shows
  an “unidentified developer” warning. Fine for beta friends, bad for strangers.
- **After notarization:** double-click opens clean, no warnings.

## CI options (later)

Notarization can run headless in GitHub Actions by importing the certificate into a
temporary keychain — see [Distributing Mac Apps With GitHub Actions](https://defn.io/2023/09/22/distributing-mac-apps-with-github-actions/),
[Federico Terzi’s guide](https://federicoterzi.com/blog/automatic-code-signing-and-notarization-for-macos-apps-using-github-actions/),
or the all-in-one [swift-app-pipeline-action](https://github.com/hurbes/swift-app-pipeline-action).
Secrets needed: base64 cert + cert password + Apple ID + team ID + app-specific password.

## Reference repos worth studying

- [jordanbaird/Ice](https://github.com/jordanbaird/Ice) — menu-bar manager; model README + release flow
- [exelban/stats](https://github.com/exelban/stats) — system monitor; mature notarized-DMG releases
- [sane-apps/SaneBar](https://github.com/sane-apps/SaneBar) — privacy-first menu-bar app framing
