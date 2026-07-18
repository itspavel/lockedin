import Foundation
import AppKit
import Combine
import UserNotifications

/// The core engine. Ticks every `interval` seconds, samples the human and agent
/// monitors, attributes elapsed time to projects, and publishes state for the UI.
@MainActor
final class Tracker: ObservableObject {
    static let interval: TimeInterval = 5
    /// Grace window: agent activity within this keeps "reading/thinking" time counting.
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

    /// Strict = input only; Engaged (default) also counts reading during agent runs.
    @Published var strictFocus: Bool = UserDefaults.standard.bool(forKey: "track.strict") {
        didSet { UserDefaults.standard.set(strictFocus, forKey: "track.strict") }
    }
    /// Menu-bar item width; narrower survives the notch on crowded bars.
    @Published var menuBarStyle: MenuBarStyle =
        MenuBarStyle(rawValue: UserDefaults.standard.string(forKey: "menubar.style") ?? "") ?? .full {
        didSet { UserDefaults.standard.set(menuBarStyle.rawValue, forKey: "menubar.style") }
    }

    /// Input older than this (seconds) counts as idle. Default 120.
    @Published var idleCutoff: TimeInterval =
        (UserDefaults.standard.object(forKey: "track.idleCutoff") as? Double) ?? 120 {
        didSet { UserDefaults.standard.set(idleCutoff, forKey: "track.idleCutoff") }
    }

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

    /// 1s countdown timer while locked — separate from the 5s tick so it stays smooth.
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

    /// Heavy file I/O runs off-main; results apply on the main actor. The reentrancy
    /// guard keeps monitor calls serial.
    private func tick() {
        rolloverIfNeeded()
        guard !ticking else { return }
        ticking = true
        let agents = self.agents
        Task.detached(priority: .utility) {
            let (active, sessions, recent) = agents.scan()
            let accrued = agents.accrueTokens()   // (tokens, prompts) — incremental, bounded
            await MainActor.run { [weak self] in
                self?.applyTick(active: active, sessions: sessions, recent: recent,
                                promptDelta: accrued.prompts, tokenDeltas: accrued.tokens)
                self?.ticking = false
            }
        }
    }

    private func applyTick(active: [AgentMonitor.ActiveAgent],
                           sessions: [AgentMonitor.AgentSession],
                           recent: [AgentMonitor.RecentProject],
                           promptDelta: Int,
                           tokenDeltas: [String: [String: TokenCounts]]) {
        let human = HumanMonitor.sample()
        let beat = EditorMonitor.read()
        editorConnected = beat != nil

        // The editor extension, when present, is the most trustworthy human signal.
        let editorEditing = (beat?.editing ?? false)
        let editorProject = beat.flatMap(EditorMonitor.project)
        if let k = beat?.keystrokes { editorKeystrokes = k }
        if let g = beat?.generated { editorGenerated = g }

        // "Engaged": dev app frontmost + agent ran recently = reading/thinking counts.
        let freshestAgentAge = recent.first?.ageSeconds ?? .infinity
        let inputActive = human.isDevApp && human.idleSeconds < idleCutoff
        // The "engaged" grace (reading/thinking during an agent run) only applies off strict mode.
        let engaged = !strictFocus && human.isDevApp && freshestAgentAge < Self.sessionHotWindow
        humanActiveNow = editorEditing || inputActive || engaged
        activeAgents = active
        activeSessions = sessions

        // Learn project name -> path so git stats can find each repo.
        for s in sessions { projectPaths[s.projectName] = s.projectPath }
        for r in recent where !r.path.isEmpty { projectPaths[r.name] = r.path }

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

        today.prompts += promptDelta
        for (proj, models) in tokenDeltas {
            for (model, c) in models {
                today.tokens[proj, default: [:]][model, default: TokenCounts()].add(c)
            }
        }

        if inputActive || !active.isEmpty {
            let snapshot = today, store = self.store
            Task.detached(priority: .utility) { store.save(snapshot) }   // write off-main too
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
        Notifier.send(title, body)
    }
}
