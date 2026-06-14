import AppKit
import CoreImage

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

    private static var colorCache: [String: NSImage] = [:]

    /// The tool's real app icon, in colour, sized for the menu bar.
    static func colored(for tool: String?, size: CGFloat = 16) -> NSImage? {
        guard let tool, let icon = icon(for: tool) else { return nil }
        let key = "\(tool.lowercased())-\(Int(size))"
        if let c = colorCache[key] { return c }
        let out = NSImage(size: NSSize(width: size, height: size))
        out.lockFocus()
        icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        out.unlockFocus()
        colorCache[key] = out
        return out
    }

    private static var monoCache: [String: NSImage] = [:]

    /// A desaturated, menu-bar-sized version of the tool's icon (real logo, not colourful).
    static func monochrome(for tool: String?, size: CGFloat = 16) -> NSImage? {
        guard let tool, let key = apps.first(where: { e in
            let t = tool.lowercased(); return e.keys.contains { t.contains($0) }
        })?.path else { return nil }
        if let cached = monoCache[key] { return cached }
        guard let icon = icon(for: tool),
              let tiff = icon.tiffRepresentation, let ci = CIImage(data: tiff),
              let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey)   // strip colour
        guard let output = filter.outputImage else { return nil }
        let rep = NSCIImageRep(ciImage: output)
        let full = NSImage(size: rep.size); full.addRepresentation(rep)

        // Redraw at menu-bar size.
        let out = NSImage(size: NSSize(width: size, height: size))
        out.lockFocus()
        full.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        out.unlockFocus()
        monoCache[key] = out
        return out
    }
}
