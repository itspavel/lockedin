import Foundation

/// "AI inside": sends a privacy-safe numeric summary of your LockedIn data to the Claude
/// Messages API and gets back a few concrete observations. Only aggregate numbers and
/// project names are sent — never code, prompts, or message content.
@MainActor
final class AIInsights: ObservableObject {
    static let shared = AIInsights()
    private let keyName = "anthropic.apiKey"

    @Published private(set) var insight: String?
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var lastGenerated: Date?
    /// True when the shown insight was loaded from today's cache (not billed this session).
    @Published private(set) var fromCache = false

    private let cacheText = "ai.insight.text"
    private let cacheDate = "ai.insight.date"     // DayLog key the cache belongs to
    private let cacheTime = "ai.insight.ts"

    init() {
        // Reuse today's insight across restarts / tab switches — one API call per day
        // unless the user hits Refresh.
        let d = UserDefaults.standard
        if d.string(forKey: cacheDate) == DayLog.key(),
           let t = d.string(forKey: cacheText), !t.isEmpty {
            insight = t
            fromCache = true
            let ts = d.double(forKey: cacheTime)
            if ts > 0 { lastGenerated = Date(timeIntervalSince1970: ts) }
        }
    }

    var apiKey: String { UserDefaults.standard.string(forKey: keyName) ?? "" }
    var hasKey: Bool { !apiKey.isEmpty }

    func setKey(_ raw: String) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { UserDefaults.standard.removeObject(forKey: keyName) }
        else { UserDefaults.standard.set(t, forKey: keyName) }
        objectWillChange.send()
    }

    func generate(tracker: Tracker) async {
        guard hasKey else { error = "Add your Anthropic API key in Settings first."; return }
        loading = true; error = nil
        let payload = await buildPayload(tracker: tracker)
        do {
            insight = try await callClaude(payload: payload)
            lastGenerated = Date()
            fromCache = false
            let d = UserDefaults.standard
            d.set(insight, forKey: cacheText)
            d.set(DayLog.key(), forKey: cacheDate)
            d.set(Date().timeIntervalSince1970, forKey: cacheTime)
        } catch {
            self.error = (error as? AIError)?.message ?? error.localizedDescription
        }
        loading = false
    }

    // MARK: - Data (numbers + project names only)

    private func buildPayload(tracker: Tracker) async -> String {
        let d = tracker.today
        let streak = tracker.streak
        let usage = UsageManager.shared

        var lines: [String] = []
        lines.append("Today (\(d.date)): you focused \(d.humanTotal.hoursCompact), agents ran \(d.agentTotal.hoursCompact). Prompts \(d.prompts). Tokens \(d.tokenTotal.total.tokensCompact), \(d.costToday.usd) API value.")

        let projToday = d.projects.sorted { $0.value.total > $1.value.total }.prefix(6)
            .map { "\($0.key): you \($0.value.human.hoursCompact), agent \($0.value.agent.hoursCompact)" }
            .joined(separator: "; ")
        if !projToday.isEmpty { lines.append("Projects today: \(projToday).") }

        if !d.hourly.isEmpty {
            let byHour = d.hourly.sorted { $0.key < $1.key }
                .map { "\($0.key):00 \(Int($0.value / 60))m" }.joined(separator: ", ")
            lines.append("Focus by hour today: \(byHour).")
        }

        if usage.connected, !usage.limits.isEmpty {
            let lims = usage.limits.map { "\($0.label) \(Int($0.percent))%" }.joined(separator: ", ")
            let reset = usage.session?.resetsAt?.untilCompact ?? "?"
            lines.append("Claude usage limits: \(lims) (session resets \(reset)). Plan \(usage.plan.label).")
        }
        lines.append("Current streak: \(streak) days.")

        // History off the main thread.
        let history = await Task.detached(priority: .userInitiated) { () -> [String] in
            let store = Store()
            let week = store.recentDays(7)
            let weekStr = week.map { "\($0.date.suffix(5)) \($0.humanTotal.hoursCompact)" }.joined(separator: ", ")
            let weekTotal = week.reduce(0.0) { $0 + $1.humanTotal }
            let active = week.filter { $0.humanTotal > 0 }.count
            let proj = store.projectTotals().prefix(8).map { p -> String in
                let agentPct = p.total > 0 ? Int(p.agent / p.total * 100) : 0
                return "\(p.name): \(p.human.hoursCompact) you / \(p.agent.hoursCompact) agent (\(agentPct)% agent), \(p.tokenTotal.tokensCompact) tokens, \(p.cost.usd)"
            }.joined(separator: "; ")
            return ["Last 7 days focused: \(weekStr). Week total \(weekTotal.hoursCompact) over \(active) active days.",
                    "All-time top projects: \(proj)."]
        }.value
        lines.append(contentsOf: history)

        return lines.joined(separator: "\n")
    }

    // MARK: - Claude Messages API (raw HTTP — no official Swift SDK)

    private enum AIError: Error {
        case http(Int, String?), badData
        var message: String {
            switch self {
            case .http(401, _): "Anthropic rejected the key (401). Check it in Settings."
            case .http(let c, let m): "Anthropic API error \(c)\(m.map { ": \($0)" } ?? "")."
            case .badData: "Couldn't read the response."
            }
        }
    }

    private func callClaude(payload: String) async throws -> String {
        let system = """
        You are an analyst inside LockedIn, a macOS time tracker that splits a builder's day \
        between their own focused (human) time and the time their AI coding agents ran. You \
        receive ONLY aggregate numbers and project names — never code, prompts, or message \
        content. Give 3–5 short, specific, genuinely useful observations a developer would \
        care about: when they focus best (peak hours), which projects are agent-heavy vs \
        hands-on, pace against their Claude usage limits, and notable patterns vs the week. \
        Reference the actual numbers. No preamble, no markdown headers — just tight lines, \
        each starting with "• ". Encouraging but honest; skip anything you can't support \
        with the data.
        """
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 1024,
            "system": system,
            "messages": [["role": "user", "content": "Here is my LockedIn data:\n\n\(payload)\n\nGive me my insights."]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AIError.badData }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
            throw AIError.http(http.statusCode, msg)
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else { throw AIError.badData }
        let text = content.filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }.joined()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
