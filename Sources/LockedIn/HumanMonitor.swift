import AppKit
import CoreGraphics

/// Detects whether the human is actively working in a dev tool right now.
/// Zero permissions: frontmost app identity via NSWorkspace, idle time via CGEventSource.
struct HumanMonitor {
    /// App names (localizedName) that count as "working" out of the box. Building isn't
    /// only coding — a real builder's day is also the browser (Figma, docs, dashboards),
    /// design tools, and team chat. Anything here can be unchecked in Settings.
    static let devAppNames: Set<String> = [
        // Editors / terminals
        "Cursor", "Code", "Visual Studio Code", "Windsurf", "Antigravity",
        "Xcode", "Terminal", "iTerm2", "Warp", "Ghostty", "kitty",
        "Zed", "Sublime Text", "IntelliJ IDEA", "PyCharm", "WebStorm", "GoLand",
        // Browsers — where Figma, docs, dashboards, and much of the work live
        "Safari", "Google Chrome", "Arc", "Brave Browser", "Microsoft Edge",
        "Firefox", "Chromium", "Dia",
        // Design / docs / coordination
        "Figma", "Notion", "Linear", "Slack", "Discord", "Obsidian", "Sketch",
    ]

    /// User customization from Settings: apps added to / removed from the default list.
    static var addedApps: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "track.appsAdded") ?? [])
    }
    static var removedApps: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "track.appsRemoved") ?? [])
    }

    /// Whether time in this app counts as work: (defaults ∪ added) − removed.
    static func isWorkApp(_ name: String) -> Bool {
        !removedApps.contains(name) && (devAppNames.contains(name) || addedApps.contains(name))
    }

    static func setWorkApp(_ name: String, _ counts: Bool) {
        var added = addedApps, removed = removedApps
        if counts { removed.remove(name); if !devAppNames.contains(name) { added.insert(name) } }
        else { added.remove(name); if devAppNames.contains(name) { removed.insert(name) } }
        UserDefaults.standard.set(Array(added).sorted(), forKey: "track.appsAdded")
        UserDefaults.standard.set(Array(removed).sorted(), forKey: "track.appsRemoved")
    }

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
        let isDev = name.map(isWorkApp) ?? false
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
