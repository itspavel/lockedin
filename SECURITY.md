# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's private
reporting instead: **Security tab → Report a vulnerability** on this repository
(github.com/itspavel/lockedin/security/advisories/new). You'll get a response within
a few days; fixes ship as fast as possible and you'll be credited if you want.

## Scope notes

- LockedIn stores everything locally (`~/Library/Application Support/LockedIn`).
  There is no server component.
- The claude.ai session cookie and the optional Anthropic API key are stored in
  `UserDefaults` on the user's Mac and are only ever sent to `claude.ai` /
  `api.anthropic.com` respectively. Reports about mishandling of either are
  especially welcome.
- The app intentionally reads only timestamps, paths, and usage counts from
  Claude Code logs. Any code path that reads message *content* is a bug — report it.

## Known limitations (pre-1.0, documented honestly)

- **Credentials live in UserDefaults, not Keychain.** The claude.ai session cookie and
  optional Anthropic API key are stored in the app's preferences plist — readable by
  other non-sandboxed apps running as the same macOS user. We moved off Keychain because
  ad-hoc dev signing changes the app's identity every build and re-prompts constantly;
  once releases are Developer-ID signed (stable identity), these move back to Keychain.
- **Update feed trust = HTTPS + Vercel account.** The in-app updater opens the DMG URL
  from our appcast over HTTPS. There is no signature on the payload yet; Sparkle with
  EdDSA-signed, notarized releases is the planned upgrade.
- **Waitlist endpoint has no rate limiting.** Signups are format-validated and stored in
  a private blob store, but a determined spammer could submit many entries.

None of these expose one user's data to another: the app has no backend, all tracking
data and credentials stay on the user's own Mac, and shipped DMGs contain only code
(binary, icon, plists — verifiable with `find LockedIn.app -type f`).
