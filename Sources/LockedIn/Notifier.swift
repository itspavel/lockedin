import AppKit

/// Delivers user notifications. Uses NSUserNotification (deprecated but works reliably for
/// locally/ad-hoc-signed apps, unlike UNUserNotificationCenter which silently drops them).
/// Attaches the coloured Claude app icon as the content image.
enum Notifier {
    static func send(_ title: String, _ body: String, claudeIcon: Bool = true) {
        NSUserNotificationCenter.default.delegate = presenter   // keep it attached
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        if claudeIcon { n.contentImage = claudeImage }
        NSUserNotificationCenter.default.deliver(n)
    }

    /// Banners are suppressed while the sending app is frontmost (e.g. clicking "Send test
    /// notification" with the Dashboard focused) unless a delegate forces presentation.
    private static let presenter = Presenter()
    private final class Presenter: NSObject, NSUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: NSUserNotificationCenter,
                                    shouldPresent notification: NSUserNotification) -> Bool { true }
    }

    /// The real, coloured Claude app icon (shown inside the notification).
    private static let claudeImage: NSImage? = {
        let path = "/Applications/Claude.app"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }()
}
