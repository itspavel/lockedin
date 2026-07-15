import Foundation

/// Per-project accumulated seconds for one calendar day.
struct ProjectTime: Codable {
    var human: TimeInterval = 0
    var agent: TimeInterval = 0
    var total: TimeInterval { human + agent }
}

/// Token usage counts. Numbers only — message content is never read or stored.
/// Cache writes are split by TTL because they're priced differently: 5-minute writes
/// bill at 1.25× input, 1-hour writes at 2× input.
struct TokenCounts: Codable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0      // 5-minute ephemeral cache writes
    var cacheWrite1h = 0    // 1-hour ephemeral cache writes
    var total: Int { input + output + cacheRead + cacheWrite + cacheWrite1h }
    mutating func add(_ o: TokenCounts) {
        input += o.input; output += o.output; cacheRead += o.cacheRead
        cacheWrite += o.cacheWrite; cacheWrite1h += o.cacheWrite1h
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
    /// Local hour (0–23) -> YOUR focused seconds in that hour. Powers the daily-rhythm
    /// strip ("when you do your focused work"). Human time only, like the headline.
    var hourly: [Int: TimeInterval] = [:]

    init(date: String) { self.date = date }

    // Decode every field defensively (decodeIfPresent) so adding a new field never makes
    // older day-log files fail to decode and disappear from history. Encoding stays synthesized.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        projects = try c.decodeIfPresent([String: ProjectTime].self, forKey: .projects) ?? [:]
        prompts = try c.decodeIfPresent(Int.self, forKey: .prompts) ?? 0
        lockSessionsCompleted = try c.decodeIfPresent(Int.self, forKey: .lockSessionsCompleted) ?? 0
        tokens = try c.decodeIfPresent([String: [String: TokenCounts]].self, forKey: .tokens) ?? [:]
        hourly = try c.decodeIfPresent([Int: TimeInterval].self, forKey: .hourly) ?? [:]
    }

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

/// A thing the desktop widget can show. The user picks which ones, in order, from the app.
enum WidgetComponent: String, CaseIterable, Codable, Identifiable {
    case total, split, projects, agents, tokens, keystrokes, streak, usage
    var id: String { rawValue }
    var label: String {
        switch self {
        case .total: "Focused total"
        case .split: "Human / agent split"
        case .projects: "Projects"
        case .agents: "Active agents"
        case .tokens: "Tokens & cost"
        case .keystrokes: "Typed vs generated"
        case .streak: "Streak"
        case .usage: "Claude usage limits"
        }
    }
    var icon: String {
        switch self {
        case .total: "clock"
        case .split: "chart.bar.fill"
        case .projects: "folder"
        case .agents: "gearshape.2"
        case .tokens: "circle.hexagongrid"
        case .keystrokes: "keyboard"
        case .streak: "flame"
        case .usage: "gauge.with.dots.needle.50percent"
        }
    }
}

/// What the desktop widget displays, configured from the dashboard. Persisted as JSON.
struct WidgetConfig: Codable {
    /// Components to show, in order. Default: the essentials.
    var components: [WidgetComponent] = [.total, .split, .projects, .agents]
    /// Projects section: false = per-project list, true = one combined summary.
    var combineProjects: Bool = false

    func isOn(_ c: WidgetComponent) -> Bool { components.contains(c) }

    static func load() -> WidgetConfig {
        guard let data = UserDefaults.standard.data(forKey: "widget.config"),
              let cfg = try? JSONDecoder().decode(WidgetConfig.self, from: data) else { return WidgetConfig() }
        return cfg
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "widget.config")
        }
    }
}

/// One day's time on a project (for the per-project activity breakdown).
struct DayPoint: Identifiable, Sendable {
    let date: String
    let human: TimeInterval
    let agent: TimeInterval
    var id: String { date }
    var total: TimeInterval { human + agent }
}

/// A project's totals across all tracked days (for the all-time Projects view).
struct ProjectAggregate: Identifiable, Sendable {
    let name: String
    var human: TimeInterval = 0
    var agent: TimeInterval = 0
    var tokens: [String: TokenCounts] = [:]   // model -> counts (for cost)
    var lastActive: String = ""               // most recent day key
    var days: [DayPoint] = []                  // per-day time (newest first)
    var id: String { name }
    var total: TimeInterval { human + agent }
    var tokenTotal: Int { tokens.values.reduce(0) { $0 + $1.total } }
    var cost: Double { tokens.reduce(0) { $0 + Pricing.cost(model: $1.key, $1.value) } }
    /// Days sorted by most active first (by YOUR focused time, for "most active days").
    var mostActiveDays: [DayPoint] { days.sorted { $0.human > $1.human } }
}

/// How much the menu-bar item shows. Narrow options exist because macOS hides menu-bar
/// items that fall under the notch when the bar is crowded.
enum MenuBarStyle: String, CaseIterable, Identifiable {
    case full, timeOnly, iconOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .full: "Time + limit %"
        case .timeOnly: "Time only"
        case .iconOnly: "Icon only"
        }
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
    /// Minutes under an hour ("42m"), then hours + minutes above ("1h 22m", "2h").
    var hoursCompact: String {
        let totalMin = Int((self / 60).rounded())
        if totalMin < 60 { return "\(totalMin)m" }
        let h = totalMin / 60, m = totalMin % 60
        return m == 0 ? "\(h)h" : String(format: "%dh %02dm", h, m)
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

extension Date {
    /// "in 1h 50m" / "in 12m" / "now" — time from now until this date.
    var untilCompact: String {
        let s = timeIntervalSinceNow
        return s <= 0 ? "now" : "in " + s.hoursCompact
    }
    /// Clock time only, e.g. "2:00 PM".
    var clockTime: String { formatted(date: .omitted, time: .shortened) }
}
