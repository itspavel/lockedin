# LockedIn — running notes

## Decided / requirements
- **Multi-agent time must be combined (cumulative), not wall-clock.** If N agents run in
  parallel on a project, agent time accrues N× per tick. The share-card stat "your agents
  did Xh" should reflect total agent work, not elapsed clock time. The widget shows how many
  agents are running. (Implemented 2026-06-13.)
- No emoji in UI — SF Symbols only.
- Zero-input is the core; Lock In (pomodoro) is an optional layer.

## Fixed 2026-06-13
- Lock In countdown now updates every second (was jumping in 5s steps with the tracking tick).
- Desktop widget locked face has Pause/Resume + Stop controls.

## Widget placement (decided 2026-06-13)
- Default: widget sits ON the desktop, BEHIND apps (desktop window level) — ambient, not in the way.
- Pin toggle (pin icon on the widget): when pinned, it floats above all windows. State persists.

## Backlog (not yet built)
- Surface keystrokes ("characters typed today") in widget + share card (extension already collects).
- Filter junk projects (/tmp, throwaway dirs) out of tracking.
- Launch-on-login (SMAppService).
- Notification muting / Do Not Disturb during Lock In.
- ~~Per-agent breakdown: tap "N agents running" to expand and see each one.~~ (Implemented 2026-06-13.)
- True WidgetKit widget + iOS companion — needs Xcode (blocked on macOS 26.2; deferred until after demand validation).

## Validation (Stage 0, from design doc)
- Post the share card on X with two framings, collect >=10 reply-with-email responses.
