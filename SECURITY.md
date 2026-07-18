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
