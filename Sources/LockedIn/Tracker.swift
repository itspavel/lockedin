import Foundation
import AppKit
import Combine
import UserNotifications

/// The core engine. Ticks every `interval` seconds, samples the human and agent
/// monitors, attributes elapsed time to projects, and publishes state for the UI.
@MainActor
final class Tracker: ObservableObject {
    static let interval: TimeInterval = 5
    /// How recently an agent must have worked for "reading/thinking" time to still count
    /// as focus on that project (you're in a live session, not walked away).
    static let sessionHotWindow: TimeInterval = 180

    // Published snapshot the menu bar binds to.
    @Published private(set) var today: DayLog
    @Published private(set) var humanActiveNow = false
    @Published private(set) var activeAgents: [AgentMonitor.ActiveAgent] = []
    @Published private(set) var activeSessions: [AgentMonitor.AgentSession] = []
    @Published private(set) var currentProject: String?
    @Published private(set) var currentTool: String?    // "Claude" / "Cursor" / "Antigravity"…
    @Published private(set) var streak = 0
    @Published private(set) var editorConnected = false

    // Lock In (focus) state — timer-driven so the countdown is smooth and pausable.
    @Published private(set) var lockActive = false
    @Published private(set) var lockPaused = false
    @Published private(set) var lockProject: String?
    @Published private(set) var lockRemaining: TimeInterval = 0
    private var lockTotal: TimeInterval = 0

    /// Total active agents across all projects right now.
    var totalAgentCount: Int { activeSessions.count }

    /// Desktop widget pinned above all windows (true) vs sitting on the desktop (false).
    @Published var widgetPinned: Bool = UserDefaults.standard.bool(forKey: "widget.pinned")
    func toggleWidgetPin() {
        widgetPinned.toggle()
        UserDefaults.standard.set(widgetPinned, forKey: "widget.pinned")
    }

    /// Desktop widget size (S/M/L).
    @Published var widgetSize: WidgetSize =
        WidgetSize(rawValue: UserDefaults.standard.string(forKey: "widget.size") ?? "") ?? .medium
    func setWidgetSize(_ s: WidgetSize) {
        widgetSize = s
        UserDefaults.standard.set(s.rawValue, forKey: "widget.size")
    }

    /// Characters typed in the editor today, from the extension heartbeat (counts only).
    @Published private(set) var editorKeystrokes = 0
    /// Characters pasted or written by the AI today (large inserts).
    @Published private(set) var editorGenerated = 0

    /// Day logs for history views (week chart, calendar, reports).
    func recentDays(_ n: Int) -> [DayLog] { store.recentDays(n) }
    func allDays() -> [DayLog] { store.allDays() }

    /// What the desktop widget shows (configured from the dashboard).
    @Published var widgetConfig: WidgetConfig = .load()
    func updateWidgetConfig(_ cfg: WidgetConfig) { widgetConfig = cfg; cfg.save() }

    private let store = Store()
    private let agents = AgentMonitor()
    private var timer: Timer?
    private var displayTimer: Timer?     // 1s tick: smooth countdown + UI refresh while locked
    private var dayKey: String

    init() {
        dayKey = DayLog.key()
        today = store.load(day: dayKey)
        streak = store.streak(endingAt: dayKey)
    }

    func start() {
        tick()
        let t = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() { timer?.invalidate() }

    // MARK: - Lock In

    func startLock(minutes: Int, project: String?) {
        lockProject = project ?? currentProject
        lockTotal = TimeInterval(minutes * 60)
        lockRemaining = lockTotal
        lockPaused = false
        lockActive = true
        FocusShield.set(true)     // best-effort system DND (no-op without the shortcut)
        startDisplayTimer()
    }

    func togglePauseLock() { lockPaused.toggle(); objectWillChange.send() }

    func endLock(completed: Bool) {
        if completed {
            today.lockSessionsCompleted += 1
            store.save(today)
            notify(title: "Session complete", body: "Nice. That's one in the books.")
        }
        lockActive = false
        lockPaused = false
        lockRemaining = 0
        FocusShield.set(false)    // lift the shield
        stopDisplayTimer()
        objectWillChange.send()
    }

    /// 1-second timer: decrements the countdown smoothly and refreshes the UI/menu bar
    /// while a focus session runs. Separate from the 5s tracking tick so the timer is
    /// smooth without sampling the monitors every second.
    private func startDisplayTimer() {
        stopDisplayTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.displayTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        displayTimer = t
    }

    private func stopDisplayTimer() { displayTimer?.invalidate(); displayTimer = nil }

    private func displayTick() {
        guard lockActive else { return }
        if !lockPaused {
            lockRemaining = max(0, lockRemaining - 1)
            if lockRemaining <= 0 { endLock(completed: true); return }
        }
        objectWillChange.send()
    }

    // MARK: - Tick

    private func tick() {
        rolloverIfNeeded()

        let human = HumanMonitor.sample()
        let (active, sessions, recent) = agents.scan()
        let beat = EditorMonitor.read()
        editorConnected = beat != nil

        // The editor extension, when present, is the most trustworthy human signal:
        // it knows the exact project and whether you're actively editing.
        let editorEditing = (beat?.editing ?? false)
        let editorProject = beat.flatMap(EditorMonitor.project)
        if let k = beat?.keystrokes { editorKeystrokes = k }
        if let g = beat?.generated { editorGenerated = g }

        // "Engaged in a live session": you're not typing, but a dev app/terminal is
        // frontmost and an agent worked on a project moments ago — i.e. you're reading the
        // output or thinking about the next prompt. That's real focus and used to fall
        // through the cracks. Auto-stops ~3 min after the agent's last activity (you left).
        let freshestAgentAge = recent.first?.ageSeconds ?? .infinity
        let engaged = human.isDevApp && freshestAgentAge < Self.sessionHotWindow
        humanActiveNow = editorEditing || human.isActive || engaged
        activeAgents = active
        activeSessions = sessions

        // Which tool is in front of you: a live Claude Code agent → Claude (it's doing the
        // token work); else the editor the sensor reports; else the frontmost dev app.
        currentTool = !active.isEmpty ? "Claude"
            : beat?.editor ?? (human.isDevApp ? human.frontmostApp : currentTool)

        if humanActiveNow {
            // Project priority for human time, all zero-permission:
            //  1. the editor extension's exact project (knows precisely),
            //  2. a live agent's project,
            //  3. the most recently touched Claude project (you bounce editor<->agent),
            //  4. the last project we attributed to (sticky within a session),
            //  5. the frontmost app name as a last resort so time is never lost.
            let proj = editorProject
                ?? active.first?.projectName
                ?? recent.first?.name
                ?? currentProject
                ?? human.frontmostApp
                ?? "untitled"
            currentProject = proj
            today.projects[proj, default: ProjectTime()].human += Self.interval
        }

        // Combined agent time: each parallel session contributes a full interval, so a
        // project with 2 agents accrues 2× — total agent work, not wall-clock.
        for agent in active {
            today.projects[agent.projectName, default: ProjectTime()].agent
                += Self.interval * TimeInterval(agent.agentCount)
            if currentProject == nil { currentProject = agent.projectName }
        }

        // Refresh prompt count cheaply (it scans today's files; fine at 5s cadence).
        today.prompts = agents.promptsToday()

        // Accrue token usage from any newly-written agent output (incremental, cheap).
        agents.accrueTokens(into: &today)

        if human.isActive || !active.isEmpty {
            store.save(today)
        }

        objectWillChange.send()
    }

    /// At local midnight, persist and roll to a fresh day.
    private func rolloverIfNeeded() {
        let now = DayLog.key()
        guard now != dayKey else { return }
        store.save(today)
        dayKey = now
        today = store.load(day: now)
        streak = store.streak(endingAt: now)
        currentProject = nil
    }

    // MARK: - Derived for UI / share card

    func lifetime(of project: String) -> TimeInterval { store.lifetimeTotal(project: project) }

    /// Populate believable numbers for preview/screenshot when no real data exists.
    func seedSample() {
        today.projects = [
            "myapp-widget": ProjectTime(human: 1.8 * 3600, agent: 3.4 * 3600),
            "client-dashboard": ProjectTime(human: 1.1 * 3600, agent: 0.5 * 3600),
            "experiments": ProjectTime(human: 0.4 * 3600, agent: 0.1 * 3600),
        ]
        today.prompts = 47
        today.tokens = [
            "myapp-widget": [
                "claude-opus-4-8": TokenCounts(input: 42_000, output: 180_000, cacheRead: 3_400_000, cacheWrite: 90_000),
                "claude-fable-5": TokenCounts(input: 8_000, output: 60_000, cacheRead: 900_000, cacheWrite: 20_000),
            ],
            "client-dashboard": [
                "claude-sonnet-4-6": TokenCounts(input: 12_000, output: 40_000, cacheRead: 600_000, cacheWrite: 15_000),
            ],
        ]
        streak = 9
        currentProject = "myapp-widget"
        currentTool = "Claude"
    }

    var sortedProjects: [(name: String, time: ProjectTime)] {
        today.projects
            .sorted { $0.value.total > $1.value.total }
            .map { ($0.key, $0.value) }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
