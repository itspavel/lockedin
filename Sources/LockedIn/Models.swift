import Foundation

/// Per-project accumulated seconds for one calendar day.
struct ProjectTime: Codable {
    var human: TimeInterval = 0
    var agent: TimeInterval = 0
    var total: TimeInterval { human + agent }
}

/// One day of tracked work. Persisted as JSON, one file per day.
struct DayLog: Codable {
    var date: String                       // "2026-06-12"
    var projects: [String: ProjectTime] = [:]
    var prompts: Int = 0                   // user prompts sent to agents today
    var lockSessionsCompleted: Int = 0

    var humanTotal: TimeInterval { projects.values.reduce(0) { $0 + $1.human } }
    var agentTotal: TimeInterval { projects.values.reduce(0) { $0 + $1.agent } }
    var total: TimeInterval { humanTotal + agentTotal }

    static func key(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }
}

/// An active Lock In focus session.
struct LockSession {
    let project: String?
    let start: Date
    let duration: TimeInterval

    var end: Date { start.addingTimeInterval(duration) }
    var remaining: TimeInterval { max(0, end.timeIntervalSinceNow) }
    var isOver: Bool { remaining <= 0 }
}

extension TimeInterval {
    /// "5.2h" style used on big numbers and share cards.
    var hoursCompact: String {
        let h = self / 3600
        return h >= 10 ? String(format: "%.0fh", h) : String(format: "%.1fh", h)
    }
    /// "3:42" style used in the menu bar (hours:minutes).
    var clockCompact: String {
        let m = Int(self) / 60
        return String(format: "%d:%02d", m / 60, m % 60)
    }
    /// "32:14" countdown style (minutes:seconds).
    var countdown: String {
        let s = Int(self.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
