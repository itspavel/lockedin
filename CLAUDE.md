# LockedIn — ambient AI-era time tracker

macOS menu-bar app. Zero-input time tracking for builders working with AI coding tools.
Splits each project's daily time between **human** and **AI agents**. Private repo:
`github.com/paveltarasov1lt-account/lockedin`. See [README.md](README.md) for the full tour.

## Run
- `./scripts/bundle.sh` → builds `build/LockedIn.app`
- `open build/LockedIn.app` (menu-bar only, no Dock icon — LSUIElement)
- `swift build` for a quick compile check (won't run the menu-bar UI standalone)
- `./scripts/dmg.sh` → drag-to-install DMG · `python3 scripts/make_icon.py` → regenerate app icon
- To verify UI: `swift run LockedIn --render <dir>` dumps PNGs (popover/widget/dashboard/sharecard).
  `--dashboard` opens the dashboard on launch; `--onboarding` forces first-run.

## How it works
- **HumanMonitor**: frontmost app (NSWorkspace) + idle time (CGEventSource). Zero permissions.
  "Working" = a **counts-as-work app** is frontmost AND input within the idle cutoff. The app
  set is user-configurable in Settings (defaults to dev tools; add Figma/browsers/etc.).
  Engaged/Strict mode + idle-timeout are tunable.
- **AgentMonitor**: watches `~/.claude/projects/*/*.jsonl`. A file with mtime < 70s = active agent.
  Project = last `cwd` in the file. Token accrual backfills today from local midnight.
  **Privacy: reads timestamps/paths/usage counts only, never content.**
- **Tracker**: 5s tick loop, attributes elapsed time to projects, persists one JSON/day in
  `~/Library/Application Support/LockedIn/days/`.
- **ClaudeUsage**: claude.ai session cookie → live limits from the `limits[]` array
  (Session / Weekly / model-scoped like **Fable**). Cookie + Anthropic API key in UserDefaults.
- **AIInsights**: optional Claude Messages API read of your numbers (cached per day).
- **UI**: SplitBar (solid=you, hatched=agents) is the signature element; the brand mark is the
  "Ring Spark" (progress ring at session % + dot). Headline "focused" = YOUR time today
  (midnight–midnight), one number; per-project rows show you + "+Xm ag". Share card exports 2x PNG.

## Rules (hard)
- **SF Symbols only — no emoji, ever** in the UI.
- **Design system**: deep violet gradient surfaces + one warm yellow accent, forced dark scheme.
  All tokens in `Sources/LockedIn/Theme.swift`. CleanMyMac-inspired (aesthetic only). Style new
  UI through `Theme` tokens; primary actions = yellow `CTAButtonStyle`; never plain system bg.
- **Focused = your (human) time**, agents shown separately. Keep the headline a single daily number.

## Built · not yet built
Built: menu-bar popover, desktop widget (non-WidgetKit), full dashboard (Projects/Calendar/
Agents/Reports/Settings), tokens+cost, usage limits, status monitor, AI insights, onboarding,
app icon, DMG. Lock In (pomodoro) was **removed** from the popover per user.
Not yet: true WidgetKit widget, iOS companion, CloudKit sync, Developer-ID signing + notarization,
Sparkle auto-update, AI-insights streaming.
