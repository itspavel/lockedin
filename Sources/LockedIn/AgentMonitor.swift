import Foundation

/// Detects active AI agent sessions by watching Claude Code's local session logs.
///
/// Privacy contract (from the design doc): we read timestamps, project paths, and
/// message counts ONLY. Prompt/conversation text is never parsed, stored, or transmitted.
///
/// Mechanism: ~/.claude/projects/<encoded-path>/<session>.jsonl gets appended while an
/// agent session runs. A recent file mtime == an active agent. The project is the last
/// "cwd" value in the file (read from the tail, key extraction only).
/// `@unchecked Sendable`: the Tracker serializes all calls (one background tick at a time
/// via a reentrancy guard), so the internal caches/offsets are never touched concurrently.
final class AgentMonitor: @unchecked Sendable {
    /// How fresh (seconds) a session file's mtime must be to count the agent as active.
    static let activeWindow: TimeInterval = 70
    /// How recently (seconds) a project was touched to still claim ambiguous human time.
    /// If you were just in project X with an agent and are now typing in your editor,
    /// you're almost certainly still on X. 30 min covers a normal back-and-forth.
    static let recentWindow: TimeInterval = 1800

    private let projectsDir: URL
    private var cwdCache: [String: String] = [:]   // file path -> last cwd
    private var offsets: [String: UInt64] = [:]    // file path -> bytes already parsed for tokens
    private let offsetURL: URL

    struct ActiveAgent {
        let projectPath: String      // absolute path of the project the agent works in
        let projectName: String      // last path component, shown in UI
        let sessionFile: URL
        var agentCount: Int = 1      // how many parallel sessions in this project
    }

    /// One live agent session (one fresh .jsonl). Multiple can share a project.
    struct AgentSession {
        let projectName: String
        let projectPath: String
        let sessionId: String        // session file stem, short id for the expanded list
        let ageSeconds: TimeInterval
    }

    /// A project touched recently, with how long ago. Used to attribute human-only time.
    struct RecentProject {
        let path: String
        let name: String
        let ageSeconds: TimeInterval
    }

    /// One directory scan → (per-project active agents with counts, every live session,
    /// recently-touched projects). Both callers share this so we walk the dir once per tick.
    /// Sessions are NOT deduped: N parallel agents in one project = N sessions, so their
    /// time accrues combined (the share-card stat reflects total agent work, not wall clock).
    func scan() -> (active: [ActiveAgent], sessions: [AgentSession], recent: [RecentProject]) {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return ([], [], []) }
        var sessions: [AgentSession] = []
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
                guard let cwd = lastCwd(in: f), !Self.isJunk(path: cwd) else { continue }
                let name = Self.displayName(for: cwd)
                if age < (recent[cwd] ?? .infinity) { recent[cwd] = age }
                if age < Self.activeWindow {
                    sessions.append(AgentSession(projectName: name, projectPath: cwd,
                                                 sessionId: f.deletingPathExtension().lastPathComponent,
                                                 ageSeconds: age))
                }
            }
        }

        // Group sessions into one ActiveAgent per project, carrying the parallel count.
        var byProject: [String: ActiveAgent] = [:]
        for s in sessions {
            if var a = byProject[s.projectPath] {
                a.agentCount += 1
                byProject[s.projectPath] = a
            } else {
                byProject[s.projectPath] = ActiveAgent(
                    projectPath: s.projectPath, projectName: s.projectName,
                    sessionFile: URL(fileURLWithPath: s.projectPath), agentCount: 1)
            }
        }

        let recentList = recent
            .map { RecentProject(path: $0.key, name: Self.displayName(for: $0.key), ageSeconds: $0.value) }
            .sorted { $0.ageSeconds < $1.ageSeconds }
        return (Array(byProject.values), sessions.sorted { $0.ageSeconds < $1.ageSeconds }, recentList)
    }

    init() {
        projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
        offsetURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LockedIn/token-offsets.json")
        if let data = try? Data(contentsOf: offsetURL),
           let saved = try? JSONDecoder().decode([String: UInt64].self, from: data) {
            offsets = saved
        }
    }

    /// Accrue token usage AND prompt counts from newly-appended JSONL lines. Tracks a byte
    /// offset per session file so we parse only NEW bytes each tick — never the whole log
    /// (they reach hundreds of MB). On first sight of a today-modified file we backfill only
    /// a bounded tail (today's activity is at the end), so startup stays cheap and bounded.
    /// Privacy: reads usage counts, model, cwd, and prompt markers only — never content.
    /// Runs off the main thread; the caller merges the deltas on the main actor.
    func accrueTokens() -> (tokens: [String: [String: TokenCounts]], prompts: Int) {
        var deltas: [String: [String: TokenCounts]] = [:]
        var prompts = 0
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return ([:], 0) }
        var changed = false
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let backfillCap: UInt64 = 12 * 1024 * 1024   // read at most the last 12 MB when backfilling

        for dir in dirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { continue }
            for f in files where f.pathExtension == "jsonl" {
                let path = f.path
                let rv = try? f.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                guard let size = rv?.fileSize else { continue }
                let eof = UInt64(size)

                guard let start = offsets[path] else {
                    // First sight: only backfill files touched today, reading a bounded tail.
                    if (rv?.contentModificationDate ?? .distantPast) >= startOfDay {
                        let from = eof > backfillCap ? eof - backfillCap : 0
                        prompts += scanRange(f, from: from, skipPartialFirst: from > 0,
                                             sinceMidnight: startOfDay, into: &deltas)
                    }
                    offsets[path] = eof; changed = true; continue
                }
                guard eof > start else { if eof < start { offsets[path] = eof; changed = true }; continue }

                // Incremental: parse only the bytes appended since last tick.
                guard let handle = try? FileHandle(forReadingFrom: f) else { continue }
                defer { try? handle.close() }
                try? handle.seek(toOffset: start)
                guard let data = try? handle.readToEnd(), !data.isEmpty,
                      let lastNL = data.lastIndex(of: 0x0A) else { continue }
                offsets[path] = start + UInt64(lastNL) + 1
                changed = true
                for lineData in data[..<lastNL].split(separator: 0x0A) {
                    let line = Data(lineData)
                    if let (project, model, counts, _) = Self.parseUsage(line) {
                        deltas[project, default: [:]][model, default: TokenCounts()].add(counts)
                    } else if Self.isUserPrompt(line) {
                        prompts += 1
                    }
                }
            }
        }
        if changed, let data = try? JSONEncoder().encode(offsets) {
            try? data.write(to: offsetURL)
        }
        return (deltas, prompts)
    }

    /// Parse a byte range of a file (from `from` to EOF) for token usage + prompt count,
    /// keeping only lines stamped since local midnight. Returns the prompt count found.
    private func scanRange(_ f: URL, from: UInt64, skipPartialFirst: Bool,
                           sinceMidnight: Date, into deltas: inout [String: [String: TokenCounts]]) -> Int {
        guard let handle = try? FileHandle(forReadingFrom: f) else { return 0 }
        defer { try? handle.close() }
        try? handle.seek(toOffset: from)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return 0 }
        // If we started mid-file, drop the first (partial) line.
        var slice = data[...]
        if skipPartialFirst, let firstNL = data.firstIndex(of: 0x0A) { slice = data[(firstNL + 1)...] }
        guard let lastNL = slice.lastIndex(of: 0x0A) else { return 0 }
        var prompts = 0
        for lineData in slice[..<lastNL].split(separator: 0x0A) {
            let line = Data(lineData)
            if let (project, model, counts, ts) = Self.parseUsage(line) {
                if let ts, ts < sinceMidnight { continue }
                deltas[project, default: [:]][model, default: TokenCounts()].add(counts)
            } else if Self.isUserPrompt(line) {
                prompts += 1
            }
        }
        return prompts
    }

    /// Cheap prompt-line detector (markers only — content never decoded). Skips huge lines.
    private static func isUserPrompt(_ line: Data) -> Bool {
        guard line.count < 262_144, let s = String(data: line, encoding: .utf8) else { return false }
        return s.contains("\"type\":\"user\"") && s.contains("\"promptId\"")
    }

    /// Pull (project, model, token counts) from one assistant JSONL line. Returns nil for
    /// non-assistant lines or junk projects. Numbers only — content is never decoded.
    private static func parseUsage(_ line: Data) -> (String, String, TokenCounts, Date?)? {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              obj["type"] as? String == "assistant",
              let cwd = obj["cwd"] as? String, !isJunk(path: cwd),
              let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else { return nil }
        let model = (message["model"] as? String) ?? "unknown"
        let ts = (obj["timestamp"] as? String).flatMap { ISO8601DateFormatter.cached.date(from: $0) }
        var c = TokenCounts()
        c.input = usage["input_tokens"] as? Int ?? 0
        c.output = usage["output_tokens"] as? Int ?? 0
        c.cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
        // Split cache writes by TTL for accurate pricing (5-min 1.25× vs 1-hour 2×).
        if let cc = usage["cache_creation"] as? [String: Any] {
            c.cacheWrite = cc["ephemeral_5m_input_tokens"] as? Int ?? 0
            c.cacheWrite1h = cc["ephemeral_1h_input_tokens"] as? Int ?? 0
        } else {
            // No breakdown — treat the total as 5-minute (the common default).
            c.cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
        }
        return (displayName(for: cwd), model, c, ts)
    }

    /// Paths we never track — scratch/throwaway locations that aren't real projects.
    /// Keeps the project list clean (no "tmp" noise from test runs or one-off scripts).
    static func isJunk(path: String) -> Bool {
        let p = path.hasSuffix("/") ? String(path.dropLast()) : path
        let leaf = (p as NSString).lastPathComponent.lowercased()
        if leaf == "tmp" || leaf.isEmpty || leaf == "/" { return true }
        let junkPrefixes = ["/tmp", "/private/tmp", "/private/var/folders", "/var/folders"]
        if junkPrefixes.contains(where: { p == $0 || p.hasPrefix($0 + "/") }) { return true }
        // Library/Caches and other non-work locations.
        if p.contains("/Library/Caches") || p.contains("/.Trash") { return true }
        return false
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

    /// Last "cwd" value in the file, read from the tail (max 64 KB). Cached per file and
    /// reused — a session file's cwd is stable, so we never re-read the tail after the
    /// first time (this alone was ~14 MB of tail reads every tick with hundreds of files).
    private func lastCwd(in file: URL) -> String? {
        if let cached = cwdCache[file.path] { return cached }
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
