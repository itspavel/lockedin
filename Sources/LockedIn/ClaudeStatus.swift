import Foundation
import SwiftUI
import AppKit
import UserNotifications

/// Live Anthropic/Claude service status from the public status page (no auth, no cookie).
/// Polls the standard StatusPage v2 API and notifies when a tracked service goes down.
@MainActor
final class StatusMonitor: ObservableObject {
    static let shared = StatusMonitor()

    struct Service: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let status: String        // operational, degraded_performance, partial_outage, major_outage, under_maintenance
        var isOK: Bool { status == "operational" }
        var color: Color {
            switch status {
            case "operational": .green
            case "degraded_performance": .yellow
            case "partial_outage": .orange
            case "major_outage": .red
            case "under_maintenance": .blue
            default: .gray
            }
        }
        var label: String {
            status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    @Published private(set) var indicator = "none"          // none/minor/major/critical
    @Published private(set) var summary = "Checking…"
    @Published private(set) var services: [Service] = []
    @Published private(set) var incidents: [String] = []
    @Published private(set) var lastChecked: Date?

    /// Which services to watch for alerts (names from the status page). Default: all.
    @Published var tracked: Set<String> = StatusMonitor.loadTracked() {
        didSet { Self.saveTracked(tracked) }
    }
    @Published var notifyOnOutage: Bool = UserDefaults.standard.object(forKey: "status.notify") as? Bool ?? true {
        didSet { UserDefaults.standard.set(notifyOnOutage, forKey: "status.notify") }
    }

    var allOperational: Bool { indicator == "none" }

    private var timer: Timer?
    private var previous: [String: String] = [:]
    private let url = URL(string: "https://status.claude.com/api/v2/summary.json")!

    func start() {
        Task { await refresh() }
        let t = Timer(timeInterval: 120, repeats: true) { [weak self] _ in   // every 2 min
            Task { await self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() async {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let s = obj["status"] as? [String: Any] {
            indicator = s["indicator"] as? String ?? "none"
            summary = s["description"] as? String ?? "—"
        }
        let comps = (obj["components"] as? [[String: Any]]) ?? []
        let list = comps
            .filter { ($0["group"] as? Bool) != true }
            .compactMap { c -> Service? in
                guard let name = c["name"] as? String, let status = c["status"] as? String else { return nil }
                return Service(name: name, status: status)
            }
        incidents = ((obj["incidents"] as? [[String: Any]]) ?? []).compactMap { $0["name"] as? String }
        lastChecked = Date()

        detectTransitions(list)
        services = list
        // First run seeds the tracked set to every service if it was never set.
        if !UserDefaults.standard.bool(forKey: "status.tracked.seeded") {
            tracked = Set(list.map(\.name))
            UserDefaults.standard.set(true, forKey: "status.tracked.seeded")
        }
    }

    /// Notify when a tracked service transitions operational → not (or recovers).
    private func detectTransitions(_ list: [Service]) {
        guard !previous.isEmpty else {     // seed silently on first fetch
            previous = Dictionary(uniqueKeysWithValues: list.map { ($0.name, $0.status) })
            return
        }
        for s in list where tracked.contains(s.name) {
            let was = previous[s.name] ?? "operational"
            if was == "operational" && s.status != "operational" {
                notify("\(s.name) is \(s.label.lowercased())", "Claude service status changed.")
            } else if was != "operational" && s.status == "operational" {
                notify("\(s.name) recovered", "Back to operational.")
            }
        }
        previous = Dictionary(uniqueKeysWithValues: list.map { ($0.name, $0.status) })
    }

    private func notify(_ title: String, _ body: String) {
        guard notifyOnOutage else { return }
        Notifier.send(title, body)
    }

    /// Fire a sample notification so the user can confirm alerts work.
    func sendTest() {
        Notifier.send("LockedIn alerts are on", "You'll be notified when a tracked Claude service goes down.")
    }

    private static func loadTracked() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "status.tracked") ?? [])
    }
    private static func saveTracked(_ s: Set<String>) {
        UserDefaults.standard.set(Array(s), forKey: "status.tracked")
    }
}

/// A compact one-line Claude status indicator (dot + summary) for the popover / widget.
struct ClaudeStatusLine: View {
    @ObservedObject private var status = StatusMonitor.shared
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(status.allOperational ? .green : .orange).frame(width: 7, height: 7)
            Text(status.allOperational ? "All Claude services operational" : status.summary)
                .lineLimit(1).truncationMode(.tail)
        }
        .font(.caption2).foregroundStyle(.secondary)
    }
}
