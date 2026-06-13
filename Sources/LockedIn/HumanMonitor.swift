import AppKit
import CoreGraphics

/// Detects whether the human is actively working in a dev tool right now.
/// Zero permissions: frontmost app identity via NSWorkspace, idle time via CGEventSource.
struct HumanMonitor {
    /// App names (localizedName) that count as "working".
    static let devAppNames: Set<String> = [
        "Cursor", "Code", "Visual Studio Code", "Windsurf", "Antigravity",
        "Xcode", "Terminal", "iTerm2", "Warp", "Ghostty", "kitty",
        "Zed", "Sublime Text", "IntelliJ IDEA", "PyCharm", "WebStorm", "GoLand",
    ]

    /// Seconds of keyboard/mouse inactivity above which the human is considered idle.
    static let idleCutoff: TimeInterval = 120

    struct Sample {
        let frontmostApp: String?
        let isDevApp: Bool
        let idleSeconds: TimeInterval
        var isActive: Bool { isDevApp && idleSeconds < HumanMonitor.idleCutoff }
    }

    static func sample() -> Sample {
        let name = NSWorkspace.shared.frontmostApplication?.localizedName
        let idle = systemIdleSeconds()
        let isDev = name.map { devAppNames.contains($0) } ?? false
        return Sample(frontmostApp: name, isDevApp: isDev, idleSeconds: idle)
    }

    /// Minimum time since the last input event of any common kind.
    private static func systemIdleSeconds() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .infinity
    }
}
