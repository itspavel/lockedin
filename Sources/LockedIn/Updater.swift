import Foundation
import AppKit

/// Lightweight update checker. Polls a JSON "appcast" for the latest version and, when a
/// newer one exists, surfaces an in-app banner + a one-time notification with the release
/// notes ("what's new"). Clicking Update opens the new DMG to install.
///
/// Note: this is a check-and-download flow, not silent in-place update. True one-click
/// Sparkle updates need a stable Developer-ID signature (Apple Developer account); our
/// ad-hoc signature changes each build, which Sparkle rejects. Slot Sparkle in once signed.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()
    private let feedKey = "update.feedURL"
    private let seenKey = "update.notifiedVersion"

    struct Release {
        let version: String
        let url: URL
        let notes: [String]
        let date: String?
    }

    @Published private(set) var available: Release?
    @Published private(set) var checking = false
    @Published private(set) var lastChecked: Date?
    @Published private(set) var upToDate = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    }

    /// Where the version feed lives. Overridable in Settings for testing / self-hosting.
    var feedURL: URL {
        if let s = UserDefaults.standard.string(forKey: feedKey), let u = URL(string: s) { return u }
        return URL(string: "https://lockedin.app/appcast.json")!
    }
    func setFeedURL(_ s: String) {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { UserDefaults.standard.removeObject(forKey: feedKey) }
        else { UserDefaults.standard.set(t, forKey: feedKey) }
    }

    private var timer: Timer?

    func start() {
        Task { await check() }
        let t = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func check(userInitiated: Bool = false) async {
        checking = true
        defer { checking = false }
        do {
            var req = URLRequest(url: feedURL)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 15
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let h = resp as? HTTPURLResponse, !(200...299).contains(h.statusCode) { return }
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = obj["version"] as? String,
                  let urlStr = obj["url"] as? String, let url = URL(string: urlStr) else { return }
            lastChecked = Date()

            let notes: [String] = (obj["notes"] as? [String]) ?? (obj["notes"] as? String).map { [$0] } ?? []
            if Self.isNewer(version, than: currentVersion) {
                available = Release(version: version, url: url, notes: notes, date: obj["date"] as? String)
                upToDate = false
                if UserDefaults.standard.string(forKey: seenKey) != version {
                    UserDefaults.standard.set(version, forKey: seenKey)
                    Notifier.send("Update available — LockedIn \(version)",
                                  notes.first ?? "A new version is ready to install.",
                                  claudeIcon: false)
                }
            } else {
                available = nil
                upToDate = true
            }
        } catch {
            // silent — updates are best-effort
        }
    }

    /// Open the new DMG in the browser to download + install.
    func openDownload() {
        guard let rel = available else { return }
        NSWorkspace.shared.open(rel.url)
    }

    /// Semantic-ish compare: "0.10" > "0.9", "1.2.0" > "1.1.9".
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
