import Foundation
import SwiftUI

/// Your Claude subscription plan — used to turn token usage into an ROI stat.
enum Plan: String, CaseIterable, Identifiable {
    case pro, max5, max20
    var id: String { rawValue }
    var label: String { switch self { case .pro: "Pro"; case .max5: "Max 5×"; case .max20: "Max 20×" } }
    var monthlyPrice: Double { switch self { case .pro: 20; case .max5: 100; case .max20: 200 } }
}

/// One usage window (e.g. the 5-hour session, or the weekly limit).
struct UsageWindow {
    var percent: Double          // 0–100
    var resetsAt: Date?
}

/// Live Claude usage limits, fetched from claude.ai with the user's own session cookie.
/// Stored in Keychain, least-access: only the orgs + usage endpoints are called.
@MainActor
final class UsageManager: ObservableObject {
    static let shared = UsageManager()
    private let cookieKey = "claude.sessionKey"

    @Published private(set) var session: UsageWindow?       // five_hour
    @Published private(set) var weekly: UsageWindow?        // seven_day
    @Published private(set) var weeklySonnet: UsageWindow?  // seven_day_sonnet
    @Published private(set) var connected = false
    @Published private(set) var error: String?
    @Published private(set) var lastChecked: Date?

    /// Subscription plan (for the ROI stat). User-set; defaults to Max 5×.
    @Published var plan: Plan = Plan(rawValue: UserDefaults.standard.string(forKey: "claude.plan") ?? "") ?? .max5 {
        didSet { UserDefaults.standard.set(plan.rawValue, forKey: "claude.plan") }
    }

    private var timer: Timer?
    // Stored in app prefs (not Keychain) so it survives rebuilds with no prompt. It's a
    // personal token on your own Mac; hardens to Keychain when the app is signed for release.
    private var sessionKey: String? { UserDefaults.standard.string(forKey: cookieKey) }

    func start() {
        timer?.invalidate()
        connected = (sessionKey?.isEmpty == false)
        guard connected else { return }
        Task { await refresh() }
        let t = Timer(timeInterval: 120, repeats: true) { [weak self] _ in Task { await self?.refresh() } }   // every 2 min
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Accepts either a bare sessionKey or the whole pasted Cookie string, and keeps only
    /// the sessionKey value (stored in Keychain — never the rest of the cookie).
    func connect(_ raw: String) {
        let key = Self.extractSessionKey(raw)
        if key.isEmpty { UserDefaults.standard.removeObject(forKey: cookieKey) }
        else { UserDefaults.standard.set(key, forKey: cookieKey) }
        connected = !key.isEmpty
        if connected { start() } else { session = nil; weekly = nil; weeklySonnet = nil }
    }

    static func extractSessionKey(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Match "sessionKey=" exactly (not "sessionKeyLC="), value runs to ';' or whitespace.
        if let r = s.range(of: "sessionKey=") {
            return String(s[r.upperBound...].prefix { $0 != ";" && !$0.isWhitespace })
        }
        return s   // assume they pasted just the key
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: cookieKey)
        connected = false; session = nil; weekly = nil; weeklySonnet = nil; error = nil
    }

    func refresh() async {
        guard let key = sessionKey, !key.isEmpty else { return }
        do {
            let org = try await fetchOrgID(key)
            let usage = try await fetchUsage(org: org, key: key)
            session = usage.0; weekly = usage.1; weeklySonnet = usage.2
            error = nil; lastChecked = Date()
        } catch {
            self.error = (error as? UsageError)?.message ?? error.localizedDescription
        }
    }

    // MARK: - Networking

    private enum UsageError: Error { case http(Int), badData, noOrg
        var message: String {
            switch self {
            case .http(let c): "claude.ai returned \(c) — cookie may be expired."
            case .badData: "Couldn't read usage data (format changed?)."
            case .noOrg: "Couldn't find your organization."
            }
        }
    }

    private func get(_ url: URL, key: String) async throws -> Any {
        var req = URLRequest(url: url)
        req.setValue("sessionKey=\(key)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("LockedIn/0.1", forHTTPHeaderField: "User-Agent")
        let cfg = URLSessionConfiguration.ephemeral   // don't persist claude.ai cookies
        let (data, resp) = try await URLSession(configuration: cfg).data(for: req)
        if let h = resp as? HTTPURLResponse, !(200...299).contains(h.statusCode) {
            throw UsageError.http(h.statusCode)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { throw UsageError.badData }
        return obj
    }

    private func fetchOrgID(_ key: String) async throws -> String {
        let obj = try await get(URL(string: "https://claude.ai/api/organizations")!, key: key)
        guard let orgs = obj as? [[String: Any]], !orgs.isEmpty else { throw UsageError.noOrg }
        // Prefer an org that can chat (the consumer plan), else the first.
        let chat = orgs.first { ($0["capabilities"] as? [String])?.contains("chat") == true }
        guard let uuid = (chat ?? orgs[0])["uuid"] as? String else { throw UsageError.noOrg }
        return uuid
    }

    private func fetchUsage(org: String, key: String) async throws -> (UsageWindow?, UsageWindow?, UsageWindow?) {
        let url = URL(string: "https://claude.ai/api/organizations/\(org)/usage")!
        guard let obj = try await get(url, key: key) as? [String: Any] else { throw UsageError.badData }
        return (window(obj["five_hour"]), window(obj["seven_day"]), window(obj["seven_day_sonnet"]))
    }

    private func window(_ any: Any?) -> UsageWindow? {
        guard let d = any as? [String: Any] else { return nil }
        // utilization may be a 0–1 fraction or a 0–100 percentage — normalize.
        let raw = (d["utilization"] as? Double) ?? Double(d["utilization"] as? Int ?? 0)
        let pct = raw <= 1.0 ? raw * 100 : raw
        var reset: Date?
        if let s = d["resets_at"] as? String { reset = ISO8601DateFormatter().date(from: s) }
        return UsageWindow(percent: pct, resetsAt: reset)
    }
}
