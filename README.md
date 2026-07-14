# LockedIn

**An ambient, zero-input time tracker for the AI era.** LockedIn is a macOS menu-bar
app that passively splits each project's day between *you* and *your AI coding agents* —
no timers to start, no buttons to press. It lives where your eyes already are: the menu
bar and an always-on desktop widget.

Built for indie hackers and solo builders who ship with Cursor and Claude Code and want
to know where their hours actually go — including the hours the agents put in.

<p align="center"><img src="Resources/icon_1024.png" width="128" alt="LockedIn icon"></p>

## Why

Manual time trackers die by week two — they live in a browser tab, out of sight, and the
start/stop friction kills them. Meanwhile the work itself has changed: you ship code while
barely typing, and every existing dev tracker is blind to the hours your agents worked.

LockedIn's answer: **zero input** (it auto-detects editor + agent activity) and a
**human/agent split** nobody else measures — the stat your build-in-public screenshot has
and theirs doesn't.

## How it works

- **HumanMonitor** — reads the frontmost app (`NSWorkspace`) and system idle time
  (`CGEventSource`). You're "working" when a tracked app is frontmost and you've given
  input recently. Zero permissions — no screen recording, no accessibility, no window
  titles. You choose which apps count in Settings.
- **AgentMonitor** — watches `~/.claude/projects/*/*.jsonl`. A session file written in the
  last ~70s means an agent is active; the project is the last `cwd` in the file. Parallel
  agents accrue cumulative time (2 agents × 30 min = 1h of agent work).
- **Tracker** — a 5-second tick loop attributes elapsed time to projects and persists one
  JSON file per day.
- **Tokens & cost** — incremental tail-read of the Claude Code logs accrues per-model token
  usage and an estimated API-equivalent cost.
- **Claude usage limits** — with your claude.ai session cookie, shows live Session / Weekly
  / model-scoped (e.g. Fable) limit % and reset times.
- **AI insights** — optional: with an Anthropic API key, Claude reads your numbers and
  tells you what they mean (peak focus hours, agent-heavy projects, pace vs limits).

### Privacy contract

LockedIn reads **timestamps, project paths, and usage counts only** — never the content of
your prompts, conversations, or code. All data stays on your Mac. The AI-insights feature
sends aggregate numbers and project names (never code or messages) to the Anthropic API,
and only when you press Generate.

## Build & run

```sh
./scripts/bundle.sh      # builds build/LockedIn.app
open build/LockedIn.app  # menu-bar only, no Dock icon (LSUIElement)

swift build              # quick compile check
./scripts/dmg.sh         # package a drag-to-install build/LockedIn-<ver>.dmg
```

Requirements: macOS 14+, Swift toolchain (no Xcode project needed — pure SwiftPM). The app
is ad-hoc signed, so first launch on another Mac needs a right-click → Open. Real
distribution needs Developer-ID signing + notarization (an Apple Developer account).

The optional editor sensor (typed-vs-AI-generated breakdown) installs via
`scripts/install-extension.sh` into Cursor / VS Code.

## Design

Deep violet gradient surfaces with a single warm accent, forced dark, SF Symbols only —
tokens live in [`Sources/LockedIn/Theme.swift`](Sources/LockedIn/Theme.swift). The
signature element is the **split bar** (solid = you, hatched = agents); the brand mark is
the "Ring Spark" — a progress ring at your session % with a center dot. The app icon is
generated from code via [`scripts/make_icon.py`](scripts/make_icon.py).

## Project layout

| Path | Role |
|---|---|
| `Sources/LockedIn/Tracker.swift` | 5s engine: sample monitors, attribute time, persist |
| `Sources/LockedIn/HumanMonitor.swift` | frontmost app + idle detection, "counts as work" list |
| `Sources/LockedIn/AgentMonitor.swift` | Claude Code JSONL scan (privacy-safe), token accrual |
| `Sources/LockedIn/Store.swift` | per-day JSON persistence, aggregates |
| `Sources/LockedIn/ClaudeUsage.swift` | claude.ai usage limits (Session/Weekly/Fable) |
| `Sources/LockedIn/AIInsights.swift` | Claude Messages API insights (cached per day) |
| `Sources/LockedIn/PopoverView.swift` | menu-bar popover |
| `Sources/LockedIn/DesktopWidgetView.swift` | always-on desktop widget |
| `Sources/LockedIn/DashboardView.swift` | full dashboard (Projects, Calendar, Reports, Settings) |

Stage 1 (the Mirror) is built; WidgetKit widget, iOS companion, and sync are later stages.
