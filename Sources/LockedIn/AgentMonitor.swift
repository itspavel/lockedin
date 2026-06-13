import Foundation

/// Detects active AI agent sessions by watching Claude Code's local session logs.
///
/// Privacy contract (from the design doc): we read timestamps, project paths, and
/// message counts ONLY. Prompt/conversation text is never parsed, stored, or transmitted.
///
/// Mechanism: ~/.claude/projects/<encoded-path>/<session>.jsonl gets appended while an
/// agent session runs. A recent file mtime == an active agent. The project is the last
/// "cwd" value in the file (read from the tail, key extraction only).
final class AgentMonitor {
    /// How fresh (seconds) a session file's mtime must be to count the agent as active.
    static let activeWindow: TimeInterval = 70
    /// How recently (seconds) a project was touched to still claim ambiguous human time.
    /// If you were just in project X with an agent and are now typing in your editor,
    /// you're almost certainly still on X. 30 min covers a normal back-and-forth.
    static let recentWindow: TimeInterval = 1800

    private let projectsDir: URL
    private var cwdCache: [String: String] = [:]   // file path -> last cwd

    struct ActiveAgent {
        let projectPath: String      // absolute path of the project the agent works in
        let projectName: String      // last path component, shown in UI
        let sessionFile: URL
    }

    /// A project touched recently, with how long ago. Used to attribute human-only time.
    struct RecentProject {
        let path: String
        let name: String
        let ageSeconds: TimeInterval
    }

    /// One directory scan → (live agents, recently-touched projects sorted newest-first).
    /// Both callers share this so we walk `~/.claude/projects` only once per tick.
    func scan() -> (active: [ActiveAgent], recent: [RecentProject]) {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return ([], []) }
        var active: [String: ActiveAgent] = [:]
        var recent: [String: TimeInterval] = [:]   // cwd -> freshest age
        let now = Date()

        for dir in dirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for f in files where f.pathExtension == "jsonl" {
                guard let mtime = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { continue }
                let age = now.timeIntervalSince(mtime)
                guard age < Self.recentWindow else { continue }
                guard let cwd = lastCwd(in: f) else { continue }
                let name = Self.displayName(for: cwd)
                if age < (recent[cwd] ?? .infinity) { recent[cwd] = age }
                if age < Self.activeWindow {
                    active[cwd] = ActiveAgent(projectPath: cwd, projectName: name, sessionFile: f)
                }
            }
        }
        let recentList = recent
            .map { RecentProject(path: $0.key, name: Self.displayName(for: $0.key), ageSeconds: $0.value) }
            .sorted { $0.ageSeconds < $1.ageSeconds }
        return (Array(active.values), recentList)
    }

    init() {
        projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    /// Folder names too generic to identify a project on their own. For these we prepend
    /// the parent so `~/work/foo/frontend` shows as "foo/frontend", not a colliding "frontend".
    private static let genericLeaves: Set<String> = [
        "src", "app", "apps", "web", "www", "frontend", "backend", "client", "server",
        "api", "lib", "packages", "code", "main", "core", "project",
    ]

    /// Stable, human-readable project identity derived from its path.
    static func displayName(for path: String) -> String {
        let parts = path.split(separator: "/").map(String.init)
        guard let leaf = parts.last else { return path }
        if genericLeaves.contains(leaf.lowercased()), parts.count >= 2 {
            return "\(parts[parts.count - 2])/\(leaf)"
        }
        return leaf
    }

    /// Count of user prompts sent today across all session files modified today.
    /// Counts lines only — message content is never decoded.
    func promptsToday() -> Int {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return 0 }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        var count = 0

        for dir in dirs {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for f in files where f.pathExtension == "jsonl" {
                guard let mtime = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                      mtime >= startOfDay else { continue }
                guard let data = fm.contents(atPath: f.path),
                      let text = String(data: data, encoding: .utf8) else { continue }
                // A human prompt line carries both markers; count, don't parse.
                for line in text.split(separator: "\n", omittingEmptySubsequences: true)
                where line.contains("\"type\":\"user\"") && line.contains("\"promptId\"") {
                    // Only count prompts stamped today (files can span midnight).
                    if let ts = extract(key: "timestamp", from: line),
                       let date = ISO8601DateFormatter.cached.date(from: ts) {
                        if date >= startOfDay { count += 1 }
                    } else {
                        count += 1
                    }
                }
            }
        }
        return count
    }

    /// Last "cwd" value in the file, read from the tail (max 64 KB), cached per file.
    private func lastCwd(in file: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return cwdCache[file.path] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let window: UInt64 = 65_536
        let offset = size > window ? size - window : 0
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return cwdCache[file.path] }

        for line in text.split(separator: "\n").reversed() {
            if let cwd = extract(key: "cwd", from: line) {
                cwdCache[file.path] = cwd
                return cwd
            }
        }
        return cwdCache[file.path]
    }

    /// Pulls a top-level string value out of a JSON line without decoding the message body.
    private func extract(key: String, from line: Substring) -> String? {
        guard let range = line.range(of: "\"\(key)\":\"") else { return nil }
        let rest = line[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let raw = String(rest[..<end])
        // cwd paths can contain escaped characters; unescape the common ones.
        return raw.replacingOccurrences(of: "\\/", with: "/")
                  .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

extension ISO8601DateFormatter {
    static let cached: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
