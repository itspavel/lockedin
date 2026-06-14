import AppKit
import SwiftUI

/// The big companion window — a normal titled, resizable window hosting the dashboard.
/// No WidgetKit/Xcode needed; it's just another window in the menu-bar app.
@MainActor
final class DashboardWindowController {
    private var window: NSWindow?
    private let tracker: Tracker

    init(tracker: Tracker) { self.tracker = tracker }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            w.title = "LockedIn"
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 860, height: 600)
            w.center()
            w.contentView = NSHostingView(rootView: DashboardView(tracker: tracker))
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
