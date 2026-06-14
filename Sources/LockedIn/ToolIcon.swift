import AppKit

/// Resolves the real macOS app icon for the tool you're using, so the widget can show
/// the actual Claude / Cursor / Antigravity / VS Code logo. Rendered grayscale by the
/// view, so it's the genuine logo but not colourful — matches the premium aesthetic.
@MainActor
enum ToolIcon {
    /// Tool-name keywords → installed app bundle. First installed match wins.
    private static let apps: [(keys: [String], path: String)] = [
        (["antigravity"], "/Applications/Antigravity IDE.app"),
        (["cursor"], "/Applications/Cursor.app"),
        (["visual studio code", "vscode", "code"], "/Applications/Visual Studio Code.app"),
        (["claude"], "/Applications/Claude.app"),
        (["windsurf"], "/Applications/Windsurf.app"),
        (["zed"], "/Applications/Zed.app"),
    ]

    private static var cache: [String: NSImage] = [:]

    /// The app icon for a tool name (e.g. "Cursor", "Antigravity IDE", "Claude"), or nil
    /// if we can't identify an installed app — the view then falls back to an SF Symbol.
    static func icon(for tool: String?) -> NSImage? {
        guard let tool, !tool.isEmpty else { return nil }
        let t = tool.lowercased()
        for entry in apps where entry.keys.contains(where: { t.contains($0) }) {
            if let cached = cache[entry.path] { return cached }
            guard FileManager.default.fileExists(atPath: entry.path) else { continue }
            let img = NSWorkspace.shared.icon(forFile: entry.path)
            cache[entry.path] = img
            return img
        }
        return nil
    }
}
