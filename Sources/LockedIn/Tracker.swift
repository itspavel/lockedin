import Foundation
import AppKit
import Combine
import UserNotifications

/// The core engine. Ticks every `interval` seconds, samples the human and agent
/// monitors, attributes elapsed time to projects, and publishes state for the UI.
@MainActor
final class Tracker: ObservableObject {
    static let interval: TimeInterval = 5

    // Published snapshot the menu bar binds to.
    @Published private(set) var today: DayLog
    @Published private(set) var humanActiveNow = false
    @Published private(set) var activeAgents: [AgentMonitor.ActiveAgent] = []
    @Published private(set) var currentProject: String?
    @Published private(set) var streak = 0
    @Published private(set) var lockSession: LockSession?
    @Published private(set) var editorConnected = false

    private let store = Store()
    private let agents = AgentMonitor()
    private var timer: Timer?
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
        lockSession = LockSession(project: project ?? currentProject,
                                  start: Date(), duration: TimeInterval(minutes * 60))
    }

    func endLock(completed: Bool) {
        if completed {
            today.lockSessionsCompleted += 1
            store.save(today)
            notify(title: "Session complete", body: "Nice. That's one in the books.")
        }
        lockSession = nil
    }

    // MARK: - Tick

    private func tick() {
        rolloverIfNeeded()

        let human = HumanMonitor.sample()
        let (active, recent) = agents.scan()
        let beat = EditorMonitor.read()
        editorConnected = beat != nil

        // The editor extension, when present, is the most trustworthy human signal:
        // it knows the exact project and whether you're actively editing.
        let editorEditing = (beat?.editing ?? false)
        let editorProject = beat.flatMap(EditorMonitor.project)
        humanActiveNow = editorEditing || human.isActive
        activeAgents = active

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

        for agent in active {
            today.projects[agent.projectName, default: ProjectTime()].agent += Self.interval
            if currentProject == nil { currentProject = agent.projectName }
        }

        // Refresh prompt count cheaply (it scans today's files; fine at 5s cadence).
        today.prompts = agents.promptsToday()

        if human.isActive || !active.isEmpty {
            store.save(today)
        }

        // Lock session expiry.
        if let s = lockSession, s.isOver {
            endLock(completed: true)
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
        streak = 9
        currentProject = "myapp-widget"
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
