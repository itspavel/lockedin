import AppKit
import UserNotifications

/// Delivers user notifications via UNUserNotificationCenter (proper authorization +
/// foreground presentation), falling back to legacy NSUserNotification when modern
/// authorization is unavailable (e.g. some ad-hoc-signed dev builds). Every step writes
/// a breadcrumb to UserDefaults (notif.debug.*) so failures are diagnosable, not silent.
enum Notifier {
    private static var modernAuthorized = false

    /// Call once at app launch: requests permission + installs delegates.
    static func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = presenter
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            modernAuthorized = granted
            let d = UserDefaults.standard
            d.set(granted, forKey: "notif.debug.granted")
            d.set(error?.localizedDescription ?? "", forKey: "notif.debug.authError")
        }
        NSUserNotificationCenter.default.delegate = legacyPresenter
    }

    static func send(_ title: String, _ body: String, claudeIcon: Bool = true) {
        if modernAuthorized {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req) { error in
                UserDefaults.standard.set(error?.localizedDescription ?? "delivered-un",
                                          forKey: "notif.debug.last")
            }
        } else {
            let n = NSUserNotification()
            n.title = title
            n.informativeText = body
            if claudeIcon { n.contentImage = claudeImage }
            NSUserNotificationCenter.default.deliver(n)
            UserDefaults.standard.set("delivered-legacy", forKey: "notif.debug.last")
        }
    }

    /// Present banners even while the app is frontmost (both APIs suppress by default).
    private static let presenter = Presenter()
    private final class Presenter: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.banner, .list, .sound])
        }
    }
    private static let legacyPresenter = LegacyPresenter()
    private final class LegacyPresenter: NSObject, NSUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: NSUserNotificationCenter,
                                    shouldPresent notification: NSUserNotification) -> Bool { true }
    }

    /// The real, coloured Claude app icon (legacy path only; UN needs attachments).
    private static let claudeImage: NSImage? = {
        let path = "/Applications/Claude.app"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }()
}
