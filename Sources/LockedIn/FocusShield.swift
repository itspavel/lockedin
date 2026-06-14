import Foundation

/// Best-effort system Focus toggle during Lock In.
///
/// macOS has no public API to switch Do Not Disturb on/off, so the only sanctioned path
/// is the Shortcuts app. If the user creates two shortcuts named exactly "LockedIn Focus On"
/// and "LockedIn Focus Off" (each running the built-in "Set Focus" action), we trigger them
/// at session start/end. If those shortcuts don't exist, this is a silent no-op — we never
/// fake a shield we can't deliver.
enum FocusShield {
    static let onShortcut = "LockedIn Focus On"
    static let offShortcut = "LockedIn Focus Off"

    static func set(_ on: Bool) {
        run(on ? onShortcut : offShortcut)
    }

    private static func run(_ shortcut: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        p.arguments = ["run", shortcut]
        p.standardOutput = nil
        p.standardError = nil           // a missing shortcut just errors quietly; ignore
        try? p.run()
    }
}
