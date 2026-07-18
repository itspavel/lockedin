import AppKit
import SwiftUI

/// The big companion window — a normal titled, resizable window hosting the dashboard.
/// No WidgetKit/Xcode needed; it's just another window in the menu-bar app.
///
/// Dock behavior (menu-bar app best practice, same as Ice/Stats): while a real window
/// is open the app becomes a regular app — Dock icon + ⌘-Tab entry — so the window can
/// be found and focused like any app. When the last window closes, it goes back to
/// menu-bar-only (.accessory).
@MainActor
final class DashboardWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let tracker: Tracker

    init(tracker: Tracker) { self.tracker = tracker }

    func show(tab: DashTab = .dashboard) {
        let wasOpen = window?.isVisible ?? false
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            w.title = "LockedIn"          // sits in the title bar, separate from content
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 860, height: 600)
            w.center()
            w.contentView = NSHostingView(rootView: DashboardView(tracker: tracker, initialTab: tab))
            w.delegate = self
            window = w
        }
        if !wasOpen { DockPolicy.windowOpened() }   // count transitions, not calls
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        DockPolicy.windowClosed()
    }
}

/// Flips the app between menu-bar-only (.accessory) and regular (.regular, with Dock
/// icon + ⌘-Tab) based on how many real windows are open.
@MainActor
enum DockPolicy {
    private static var openWindows = 0

    static func windowOpened() {
        openWindows += 1
        NSApp.setActivationPolicy(.regular)
    }

    static func windowClosed() {
        openWindows = max(0, openWindows - 1)
        if openWindows == 0 {
            // Back to a pure menu-bar app once the last window is gone.
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
