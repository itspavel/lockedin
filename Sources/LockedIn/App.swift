import SwiftUI
import AppKit
import UserNotifications

@main
struct LockedInApp {
    static func main() {
        let app = NSApplication.shared

        // Preview/render mode: `LockedIn --render <dir>` dumps UI PNGs and exits.
        if let i = CommandLine.arguments.firstIndex(of: "--render"),
           i + 1 < CommandLine.arguments.count {
            app.setActivationPolicy(.prohibited)
            MainActor.assumeIsolated { Preview.render(to: CommandLine.arguments[i + 1]) }
            return
        }

        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // no Dock icon, menu bar only
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let tracker = Tracker()
    private var widget: WidgetWindowController!
    private var dashboard: DashboardWindowController!
    private var cancellable: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        tracker.start()

        widget = WidgetWindowController(tracker: tracker)
        widget.restoreVisibility()
        dashboard = DashboardWindowController(tracker: tracker)

        StatusMonitor.shared.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 460)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(tracker: tracker,
                                  onToggleWidget: { [weak self] in self?.widget.toggle() },
                                  onOpenDashboard: { [weak self] in self?.popover.performClose(nil); self?.dashboard.show() })
        )

        // Repaint the menu bar label on every tracker change.
        cancellable = tracker.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.refreshStatusItem() }
        }
        refreshStatusItem()

        if CommandLine.arguments.contains("--dashboard") { dashboard.show() }
        if CommandLine.arguments.contains("--test-notif") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { StatusMonitor.shared.sendTest() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        widget?.savePosition()
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }

        if tracker.lockActive {
            button.image = symbol(tracker.lockPaused ? "pause.fill" : "lock.fill")
            button.title = " " + tracker.lockRemaining.countdown
            return
        }

        // Show the current tool's real logo (grayscale) when active and identifiable;
        // otherwise a state symbol.
        if (tracker.humanActiveNow || !tracker.activeSessions.isEmpty),
           let logo = ToolIcon.monochrome(for: tracker.currentTool, size: 16) {
            logo.isTemplate = false
            button.image = logo
        } else {
            let agentRunning = !tracker.activeSessions.isEmpty
            let name = agentRunning ? "gearshape.2.fill"
                     : tracker.humanActiveNow ? "circle.fill" : "circle"
            button.image = symbol(name)
        }
        // Same format as the widget (1.4h), not h:mm — avoids "1:22 vs 1.4h" confusion.
        button.title = " " + tracker.today.total.hoursCompact
    }

    private func symbol(_ name: String) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
