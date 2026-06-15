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
    /// as focus on that project. 5 min so flipping to another window/monitor while an agent
    /// runs doesn't pause the clock; still auto-stops once the session goes truly cold.
    static let sessionHotWindow: TimeInterval = 300

    // Published snapshot the menu bar binds to.
    @Published private(set) var today: DayLog
    @Published private(set) var humanActiveNow = false
    @Published private(set) var activeAgents: [AgentMonitor.ActiveAgent] = []
    @Published private(set) var activeSessions: [AgentMonitor.AgentSession] = []
    @Published private(set) var currentProject: String?
    @Published private(set) var currentTool: String?    // "Claude" / "Cursor" / "Antigravity"…
    /// Project name -> its filesystem path (learned from agent sessions this run).
    /// Powers git output stats; session-scoped since git stats are always live/today.
    @Published private(set) var projectPaths: [String: String] = [:]
    @Published private(set) var streak = 0
    @Published private(set) var editorConnected = false

    /// Focused (human) time within the current Claude 5-hour session window. Resets when the
    /// window rolls over. Falls back to today's human total when no cookie is connected.
    @Published private(set) var sessionFocused: TimeInterval = 0
    private var sessionWindowEnd: Date?

    /// Whether we have a live Claude session window to scope focused time to.
    var hasSessionWindow: Bool { sessionWindowEnd != nil }
    /// The headline focused number: session-scoped when a window is known, else today.
    var headlineFocused: TimeInterval { hasSessionWindow ? sessionFocused : today.humanTotal }
    /// When the current session window resets (subtitle under the headline).
    var sessionResetsAt: Date? { sessionWindowEnd }

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

        // Restore session-scoped focus if its window hasn't ended yet.
        let storedEnd = UserDefaults.standard.double(forKey: "session.windowEnd")
        if storedEnd > 0, Date(timeIntervalSince1970: storedEnd) > Date() {
            sessionWindowEnd = Date(timeIntervalSince1970: storedEnd)
            sessionFocused = UserDefaults.standard.double(forKey: "session.focused")
        }
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

    private var ticking = false

    /// Scheduler: the heavy file scanning runs OFF the main thread so the UI (menu bar,
    /// popover, widget) stays responsive even with huge Claude logs. Results are applied
    /// back on the main actor. A reentrancy guard skips a tick if the previous I/O is
    /// still running (so calls to the monitor are never concurrent).
    private func tick() {
        rolloverIfNeeded()
        guard !ticking else { return }
        ticking = true
        let agents = self.agents
        Task.detached(priority: .utility) {
            let (active, sessions, recent) = agents.scan()
            let prompts = agents.promptsToday()
            let tokenDeltas = agents.accrueTokens()
            await MainActor.run { [weak self] in
                self?.applyTick(active: active, sessions: sessions, recent: recent,
                                prompts: prompts, tokenDeltas: tokenDeltas)
                self?.ticking = false
            }
        }
    }

    private func applyTick(active: [AgentMonitor.ActiveAgent],
                           sessions: [AgentMonitor.AgentSession],
                           recent: [AgentMonitor.RecentProject],
                           prompts: Int,
                           tokenDeltas: [String: [String: TokenCounts]]) {
        let human = HumanMonitor.sample()
        let beat = EditorMonitor.read()
        editorConnected = beat != nil

        // The editor extension, when present, is the most trustworthy human signal.
        let editorEditing = (beat?.editing ?? false)
        let editorProject = beat.flatMap(EditorMonitor.project)
        if let k = beat?.keystrokes { editorKeystrokes = k }
        if let g = beat?.generated { editorGenerated = g }

        // "Engaged in a live session": not typing, but a dev app is frontmost and an agent
        // worked moments ago — you're reading output / thinking. Auto-stops when it goes cold.
        let freshestAgentAge = recent.first?.ageSeconds ?? .infinity
        let engaged = human.isDevApp && freshestAgentAge < Self.sessionHotWindow
        humanActiveNow = editorEditing || human.isActive || engaged
        activeAgents = active
        activeSessions = sessions

        // Learn project name -> path so git stats can find each repo.
        for s in sessions { projectPaths[s.projectName] = s.projectPath }
        for r in recent where !r.path.isEmpty { projectPaths[r.name] = r.path }

        updateSessionFocused(humanActive: humanActiveNow)

        currentTool = !active.isEmpty ? "Claude"
            : beat?.editor ?? (human.isDevApp ? human.frontmostApp : currentTool)

        if humanActiveNow {
            let proj = editorProject
                ?? active.first?.projectName
                ?? recent.first?.name
                ?? currentProject
                ?? human.frontmostApp
                ?? "untitled"
            currentProject = proj
            today.projects[proj, default: ProjectTime()].human += Self.interval
            let hour = Calendar.current.component(.hour, from: Date())
            today.hourly[hour, default: 0] += Self.interval
        }

        // Combined agent time: each parallel session contributes a full interval.
        for agent in active {
            today.projects[agent.projectName, default: ProjectTime()].agent
                += Self.interval * TimeInterval(agent.agentCount)
            if currentProject == nil { currentProject = agent.projectName }
        }

        today.prompts = prompts
        for (proj, models) in tokenDeltas {
            for (model, c) in models {
                today.tokens[proj, default: [:]][model, default: TokenCounts()].add(c)
            }
        }

        if human.isActive || !active.isEmpty {
            let snapshot = today, store = self.store
            Task.detached(priority: .utility) { store.save(snapshot) }   // write off-main too
        }
        objectWillChange.send()
    }

    /// Keep `sessionFocused` scoped to the live Claude 5h window. We detect a window
    /// rollover when the API's `resets_at` jumps forward, and zero the counter then.
    private func updateSessionFocused(humanActive: Bool) {
        let usage = UsageManager.shared
        if usage.connected, let end = usage.session?.resetsAt {
            if let cur = sessionWindowEnd {
                if end > cur.addingTimeInterval(60) { sessionFocused = 0; sessionWindowEnd = end }
            } else {
                sessionWindowEnd = end          // first window seen this run
            }
        } else if let cur = sessionWindowEnd, !usage.connected || cur < Date() {
            sessionFocused = 0; sessionWindowEnd = nil   // disconnected or window expired
        }
        if humanActive, sessionWindowEnd != nil { sessionFocused += Self.interval }
        UserDefaults.standard.set(sessionFocused, forKey: "session.focused")
        UserDefaults.standard.set(sessionWindowEnd?.timeIntervalSince1970 ?? 0, forKey: "session.windowEnd")
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
        Notifier.send(title, body)
    }
}
