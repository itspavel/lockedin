import Foundation

/// Loads and saves DayLog JSON files in Application Support.
/// One file per day: ~/Library/Application Support/LockedIn/days/2026-06-12.json
/// `Sendable`: only immutable state (the directory URL); all I/O is stateless file reads/writes.
final class Store: @unchecked Sendable {
    private let dir: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("LockedIn/days", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func url(for key: String) -> URL {
        dir.appendingPathComponent("\(key).json")
    }

    func load(day key: String) -> DayLog {
        let u = url(for: key)
        if let data = try? Data(contentsOf: u),
           let log = try? JSONDecoder().decode(DayLog.self, from: data) {
            return log
        }
        return DayLog(date: key)
    }

    func save(_ log: DayLog) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(log) else { return }
        try? data.write(to: url(for: log.date), options: .atomic)
    }

    /// Consecutive days (ending today) that have any tracked time. Powers the streak badge.
    func streak(endingAt key: String) -> Int {
        var count = 0
        var date = Date()
        let cal = Calendar.current
        while true {
            let k = DayLog.key(for: date)
            let log = load(day: k)
            if log.total > 60 { count += 1 } else { break }
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return count
    }

    /// The last `n` days (oldest → newest), loading empty logs for days with no file.
    /// Powers the week chart and history views.
    func recentDays(_ n: Int, endingAt date: Date = Date()) -> [DayLog] {
        let cal = Calendar.current
        var out: [DayLog] = []
        for offset in stride(from: n - 1, through: 0, by: -1) {
            guard let d = cal.date(byAdding: .day, value: -offset, to: date) else { continue }
            out.append(load(day: DayLog.key(for: d)))
        }
        return out
    }

    /// Every saved day (newest first). Powers the all-time totals and reports.
    func allDays() -> [DayLog] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(DayLog.self, from: $0) }
            .sorted { $0.date > $1.date }
    }

    /// Lifetime total seconds for a project across all saved days.
    func lifetimeTotal(project: String) -> TimeInterval {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return 0 }
        var sum: TimeInterval = 0
        for f in files where f.pathExtension == "json" {
            if let data = try? Data(contentsOf: f),
               let log = try? JSONDecoder().decode(DayLog.self, from: data),
               let p = log.projects[project] {
                sum += p.total
            }
        }
        return sum
    }
}
