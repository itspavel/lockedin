import Foundation

/// Per-project accumulated seconds for one calendar day.
struct ProjectTime: Codable {
    var human: TimeInterval = 0
    var agent: TimeInterval = 0
    var total: TimeInterval { human + agent }
}

/// Token usage counts. Numbers only — message content is never read or stored.
struct TokenCounts: Codable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0
    var total: Int { input + output + cacheRead + cacheWrite }
    mutating func add(_ o: TokenCounts) {
        input += o.input; output += o.output; cacheRead += o.cacheRead; cacheWrite += o.cacheWrite
    }
}

/// One day of tracked work. Persisted as JSON, one file per day.
struct DayLog: Codable {
    var date: String                       // "2026-06-12"
    var projects: [String: ProjectTime] = [:]
    var prompts: Int = 0                   // user prompts sent to agents today
    var lockSessionsCompleted: Int = 0
    /// project -> model -> token counts. Lets us derive per-project totals,
    /// the model mix, and accurate cost (each model priced at its own rate).
    var tokens: [String: [String: TokenCounts]] = [:]

    var humanTotal: TimeInterval { projects.values.reduce(0) { $0 + $1.human } }
    var agentTotal: TimeInterval { projects.values.reduce(0) { $0 + $1.agent } }
    var total: TimeInterval { humanTotal + agentTotal }

    /// All tokens today across every project and model.
    var tokenTotal: TokenCounts {
        var t = TokenCounts()
        for models in tokens.values { for c in models.values { t.add(c) } }
        return t
    }
    /// Estimated USD cost today, summed per model at that model's rate.
    var costToday: Double {
        var sum = 0.0
        for models in tokens.values {
            for (model, c) in models { sum += Pricing.cost(model: model, c) }
        }
        return sum
    }
    /// Tokens per model (the model mix), summed across projects.
    var tokensByModel: [String: TokenCounts] {
        var out: [String: TokenCounts] = [:]
        for models in tokens.values {
            for (model, c) in models { out[model, default: TokenCounts()].add(c) }
        }
        return out
    }

    static func key(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }
}

/// Desktop widget size presets. Each shows progressively more detail.
enum WidgetSize: String, CaseIterable, Identifiable {
    case small, medium, large, xlarge
    var id: String { rawValue }
    var width: CGFloat {
        switch self { case .small: 190; case .medium: 240; case .large: 290; case .xlarge: 350 }
    }
    var label: String {
        switch self { case .small: "S"; case .medium: "M"; case .large: "L"; case .xlarge: "XL" }
    }
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
