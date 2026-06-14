import Foundation

/// Reads the heartbeat written by the LockedIn Cursor/VS Code extension.
/// This is the highest-quality human signal we get: the editor knows exactly which
/// project and file you're in, and how many characters you've typed — no guessing,
/// no OS permissions. Absent (extension not installed) we fall back to HumanMonitor.
struct EditorMonitor {
    /// Heartbeats older than this mean the editor is closed or the extension is gone.
    static let staleAfter: TimeInterval = 30

    struct Beat: Codable {
        let editor: String?
        let projectPath: String?
        let file: String?
        let language: String?
        let keystrokes: Int?
        let editing: Bool?
        let focused: Bool?
        let ts: String?
    }

    private static let url = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("LockedIn/editor-heartbeat.json")

    /// Current beat if fresh, else nil.
    static func read() -> Beat? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(mtime) < staleAfter,
              let data = try? Data(contentsOf: url),
              let beat = try? JSONDecoder().decode(Beat.self, from: data) else { return nil }
        return beat
    }

    /// Project display name from the heartbeat, via the same rules as AgentMonitor.
    static func project(from beat: Beat) -> String? {
        guard let p = beat.projectPath, !p.isEmpty, !AgentMonitor.isJunk(path: p) else { return nil }
        return AgentMonitor.displayName(for: p)
    }
}
