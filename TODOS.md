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

## LATER — the dashboard app (Stage 2, the "big app") — DIRECTION APPROVED 2026-06-14
Wireframe approved (/tmp/lockedin-dashboard-sketch.html). Structure: left sidebar tabs +
main content pane (macOS Settings-style, but Dashboard-led). SF Symbols, no emoji.
Sidebar tabs (all wanted for v1):
- **Dashboard** (hero): big total + human/agent split bar; Day/Week/Month/All switcher;
  stat cards (tokens+cost, prompts, typed-vs-AI, focus blocks); weekly stacked bar chart;
  projects table (split, you, agents, tokens, cost, last active).
- **Projects**: per-project drilldown; rename/merge/archive; goals, colors, hourly rate.
- **Calendar**: day-by-day timeline of projects + focus sessions.
- **Agents & Tokens**: token usage, cost, model mix, per-agent breakdown.
- **Reports / Export**: CSV export, billing-style reports (freelancer angle).
- **Settings**: editor sensors, focus-shield shortcut, launch-at-login, privacy.
Build the rich data layer first (Stage 1.5 below) — the dashboard is then just a reader.
This shared data layer is also what justifies WidgetKit + iOS later.

## New ideas / requirements (2026-06-15)
- COST FRAMING: the $ shown is API-equivalent (pay-as-you-go). On a subscription you pay a
  flat fee, so frame it as "value you got from your plan" (≈$X API value). Done on dashboard;
  apply same wording on widget/share card.
- CLAUDE CODE LIMITS BAR (like ClaudeUsageBar): session 5h / weekly 7d / weekly-Sonnet % used
  + reset times. Accurate data needs the claude.ai session cookie (the reference app uses
  "Set Session Cookie") — Claude Code doesn't expose rolling-window % locally. Approach:
  optional "Set session cookie" in Settings → fetch usage → show limits bar on widget/menu/dash.
- PROJECT PERSISTENCE: data is saved per day (history kept), but UI currently shows TODAY's
  projects only. Add an all-time/aggregated Projects view (Store.allDays already supports it)
  so every project ever worked on is listed and stays.
- CURSOR: time IS tracked (extension + frontmost). Cursor's OWN AI tokens are NOT visible
  (no public log) — only Claude Code tokens. Document this clearly in the app.
- MONETIZE (later): paid tier once it's polished.
- DESIGN (later): real visual design pass (current is functional mock).
- AI INSIDE (later): a connected AI feature — possibly a Claude Code skill / MCP / API that
  reads the project and surfaces insights. Shape TBD.
- PERF: tick does 3 directory walks of ~/.claude/projects on the MAIN thread every 5s; with
  huge logs this causes periodic micro-stutter. Fix: one shared scan, move file I/O off the
  main actor, throttle UI updates.

## Backlog (not yet built)
- App icon + first-run onboarding (find the menu bar item; install the Cursor extension).
- Package Cursor extension as .vsix; publish or one-click install.
- Notarized .dmg + landing page so others can download.
- App-name fallback ("Cursor") still used when no project signal — consider git-root inference.
- True WidgetKit widget + iOS companion — needs Xcode (blocked on macOS 26.2; deferred until after demand validation).

## Validation (Stage 0, from design doc)
- Post the share card on X with two framings, collect >=10 reply-with-email responses.
