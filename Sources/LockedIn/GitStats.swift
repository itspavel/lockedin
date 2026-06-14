import Foundation

/// Today's real code output for a repo: commits since local midnight + lines changed.
/// Numbers only — file names and diffs are never read or stored (privacy contract).
struct GitOutput: Sendable {
    var added = 0
    var deleted = 0
    var commits = 0
    var hasOutput: Bool { added > 0 || deleted > 0 || commits > 0 }

    mutating func add(_ o: GitOutput) { added += o.added; deleted += o.deleted; commits += o.commits }
}

/// Shells out to `git` for per-repo daily output stats. Blocking — call off the main thread.
enum GitStats {
    /// Commits made today + net lines (today's commits via numstat, plus the current
    /// uncommitted working tree so in-progress work still shows). nil if not a git repo.
    static func today(path: String) -> GitOutput? {
        guard isRepo(path) else { return nil }
        var out = GitOutput()

        if let s = run(["log", "--since=midnight", "--oneline"], in: path) {
            out.commits = s.split(separator: "\n").filter { !$0.isEmpty }.count
        }
        // Lines committed today, then uncommitted working-tree changes on top.
        for cmd in [["log", "--since=midnight", "--numstat", "--pretty=tformat:"],
                    ["diff", "--numstat"]] {
            guard let s = run(cmd, in: path) else { continue }
            for line in s.split(separator: "\n") {
                let cols = line.split(separator: "\t")
                guard cols.count >= 2 else { continue }   // binary files show "-" — skipped
                out.added += Int(cols[0]) ?? 0
                out.deleted += Int(cols[1]) ?? 0
            }
        }
        return out
    }

    private static func isRepo(_ path: String) -> Bool {
        run(["rev-parse", "--is-inside-work-tree"], in: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    private static func run(_ args: [String], in dir: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", dir] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()   // swallow stderr (e.g. "not a git repository")
        guard (try? p.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
