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
        let active = agents.activeAgents()
        humanActiveNow = human.isActive
        activeAgents = active

        // Attribute the elapsed interval.
        if human.isActive {
            // Prefer the project an agent is in (folder name); else the frontmost app
            // gives us liveness but not a project, so fall back to last known project.
            let proj = active.first?.projectName ?? currentProject ?? human.frontmostApp ?? "untitled"
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
