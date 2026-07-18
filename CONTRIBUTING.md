# Contributing to LockedIn

Thanks for wanting to help! LockedIn is a macOS menu-bar app built with pure SwiftPM —
no Xcode project required.

## Getting started

```sh
git clone https://github.com/paveltarasov1lt-account/lockedin.git
cd lockedin
./scripts/bundle.sh      # build build/LockedIn.app
open build/LockedIn.app
```

`swift build` gives you a fast compile check. `swift run LockedIn --render /tmp/preview`
dumps PNGs of every surface (popover / widget / dashboard / share card) — our
"Xcode preview" without Xcode. `--dashboard` opens the dashboard on launch,
`--onboarding` forces the first-run flow.

## Ground rules

- **Privacy is the product.** Never read prompt/conversation/code *content* from
  Claude Code logs — timestamps, paths, and usage counts only. PRs that violate
  this are rejected regardless of the feature.
- **SF Symbols only, no emoji** anywhere in the UI.
- Style new UI through the tokens in `Sources/LockedIn/Theme.swift` — violet gradient
  surfaces, one warm yellow accent, forced dark. Primary actions use `CTAButtonStyle`.
- Performance matters: the tick loop runs every 5s against potentially hundreds of MB
  of logs. File reads must be incremental/bounded (see `AgentMonitor.accrueTokens`).
  Never do file I/O on the main thread.

## PRs

1. Fork, branch from `main`, keep the change focused.
2. `swift build` must pass (CI enforces it).
3. Describe *what* and *why*; screenshots for UI changes (the `--render` flag helps).

## The landing site

`landing/` is a Next.js app (`pnpm dev`). Brand tokens live in
`landing/src/app/globals.css`.

## Bugs & ideas

Open an issue with the template. For anything security-related, see
[SECURITY.md](SECURITY.md) — don't open a public issue.
