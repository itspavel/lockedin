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

## NOW — functionality + widget enrichment (Stage 1.5)
Build order, highest value first:
0. FIX focus-detection gap (core correctness). Today time only counts while typing
   (<120s input) or while an agent is mid-response. The in-between — reading the agent's
   output, thinking about the next prompt — is uncounted. Fix: if a Claude Code session
   on the current project was active recently (~3 min) AND a dev app/terminal is frontmost,
   count it as focused time even without keystrokes. Still stops when you walk away
   (frontmost changes) or the session goes stale + no input.
1. Token + cost tracking — parse `usage` from Claude Code JSONL (input/output/cache per
   message), accumulate per project per day, estimate cost per model. Incremental tail-read
   (byte offset per file) so we don't reparse huge logs each tick. Privacy: numbers only.
2. Typed vs AI-generated chars — extension: a small change (~1 char) = typing; a big insert
   (paste / AI edit) = generated. Track both separately. Surface "typed" as the human stat.
3. Model mix (Opus/Sonnet/Fable/Haiku) per day — falls out of #1.
4. Lines +/- per project (git diff --stat) and commits today / branch.
5. Hourly activity sparkline — store per-hour buckets in the day log.
6. Derived: current + longest focus block, human:agent ratio headline, weekly total.

## LATER — the dashboard app (Stage 2, the "big app")
Full companion window (not just the menu-bar popover), Clockify-style:
- History: totals across all projects over time (day/week/month), per project drilldown.
- Calendar view: which projects on which days, focus sessions on a timeline.
- Projects view: rename/merge/archive projects, set goals, colors, hourly rate.
- Settings dashboard: editor sensors, focus-shield shortcut, launch-at-login, privacy.
- Reports/export (CSV) for the freelancer-billing use case.
- This is the surface that justifies WidgetKit + iOS later (shared data layer).
Note: keep the data layer (day logs) clean and rich now so the dashboard is just a reader.

## Backlog (not yet built)
- App icon + first-run onboarding (find the menu bar item; install the Cursor extension).
- Package Cursor extension as .vsix; publish or one-click install.
- Notarized .dmg + landing page so others can download.
- App-name fallback ("Cursor") still used when no project signal — consider git-root inference.
- True WidgetKit widget + iOS companion — needs Xcode (blocked on macOS 26.2; deferred until after demand validation).

## Validation (Stage 0, from design doc)
- Post the share card on X with two framings, collect >=10 reply-with-email responses.
