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

## Daily-drivable polish (done 2026-06-13)
- ~~Filter junk projects (/tmp, /var/folders, Caches) — AgentMonitor.isJunk.~~
- ~~Launch-on-login (SMAppService) — toggle in popover "..." menu.~~
- ~~Notification muting during Lock In — FocusShield via Shortcuts (see setup note below).~~
- ~~Surface keystrokes ("chars typed") on L/XL widget.~~
- ~~Per-agent breakdown: tap "N agents running".~~

### Focus shield setup (for full system DND during Lock In)
macOS has no public DND API. To get real system Do Not Disturb during Lock In, create two
Shortcuts named exactly "LockedIn Focus On" and "LockedIn Focus Off", each with the built-in
"Set Focus" action (On / Off). LockedIn triggers them automatically. Without them it's a no-op
(LockedIn still never posts its own notifications mid-session).

## Backlog (not yet built)
- App icon + first-run onboarding (find the menu bar item; install the Cursor extension).
- Package Cursor extension as .vsix; publish or one-click install.
- Notarized .dmg + landing page so others can download.
- App-name fallback ("Cursor") still used when no project signal — consider git-root inference.
- True WidgetKit widget + iOS companion — needs Xcode (blocked on macOS 26.2; deferred until after demand validation).

## Validation (Stage 0, from design doc)
- Post the share card on X with two framings, collect >=10 reply-with-email responses.
