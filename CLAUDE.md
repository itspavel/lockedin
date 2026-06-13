# LockedIn — ambient AI-era time tracker (Stage 1: the Mirror)

macOS menu-bar app. Zero-input time tracking for builders working with AI coding tools.
Splits each project's daily time between **human** and **AI agents**.

## Run
- `./scripts/bundle.sh` → builds `build/LockedIn.app`
- `open build/LockedIn.app` (menu-bar only, no Dock icon — LSUIElement)
- `swift build` for a quick compile check (won't run the menu-bar UI standalone)

## How it works
- **HumanMonitor**: frontmost app (NSWorkspace) + idle time (CGEventSource). Zero permissions.
  "Working" = a known dev app is frontmost AND input within last 120s.
- **AgentMonitor**: watches `~/.claude/projects/*/*.jsonl`. A file with mtime < 70s = active agent.
  Project = last `cwd` in the file. **Privacy: reads timestamps/paths/message counts only, never content.**
- **Tracker**: 5s tick loop, attributes elapsed time to projects, persists one JSON/day in
  `~/Library/Application Support/LockedIn/days/`.
- **UI**: SplitBar (solid=human, hatched=agent) is the signature element. Lock In = pomodoro on top.
  Share card = achievement poster, exports 2x PNG. **SF Symbols only — no emoji, ever.**

## Design source of truth
`~/.gstack/projects/appleapp.widget./paveltarasov-none-design-20260612-230836.md`

## Not yet built (later stages)
WidgetKit desktop widget, notification muting during Lock In, onboarding, iOS companion, sync.
