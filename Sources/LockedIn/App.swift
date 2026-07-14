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
    private var onboarding: OnboardingWindowController!
    private var cancellable: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        tracker.start()

        widget = WidgetWindowController(tracker: tracker)
        widget.restoreVisibility()
        dashboard = DashboardWindowController(tracker: tracker)

        StatusMonitor.shared.start()
        UsageManager.shared.start()
        Updater.shared.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)   // purple-brand content, dark chrome
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

        // First-run welcome (or forced with --onboarding).
        onboarding = OnboardingWindowController()
        if OnboardingWindowController.shouldShow || CommandLine.arguments.contains("--onboarding") {
            onboarding.show(onOpenSettings: { [weak self] in self?.dashboard.show(tab: .settings) })
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

        // Show the current tool's real logo, in colour, when active and identifiable;
        // otherwise the brand ring (option 1a) at the live Claude session %.
        if (tracker.humanActiveNow || !tracker.activeSessions.isEmpty),
           let logo = ToolIcon.colored(for: tracker.currentTool, size: 16) {
            logo.isTemplate = false
            button.image = logo
        } else {
            let pct = UsageManager.shared.session?.percent ?? 70
            let active = tracker.humanActiveNow || !tracker.activeSessions.isEmpty
            button.image = Self.ringImage(progress: pct / 100, dimmed: !active)
        }
        // Your focused time today (midnight–midnight), plus the session usage % when connected.
        var title = " " + tracker.today.humanTotal.hoursCompact
        if UsageManager.shared.connected, let p = UsageManager.shared.session?.percent {
            title += " · \(Int(p))%"
        }
        button.title = title
    }

    private func symbol(_ name: String) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
    }

    /// The brand mark as a menu-bar template image: ring at `progress` + center dot
    /// (design option 1a). Template so it adapts to menu-bar light/dark.
    static func ringImage(progress: Double, dimmed: Bool) -> NSImage {
        let s: CGFloat = 16
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
            let lw: CGFloat = 2.1
            let r = s / 2 - lw / 2 - 0.5
            let c = NSPoint(x: s / 2, y: s / 2)
            let alpha: CGFloat = dimmed ? 0.45 : 1.0

            let track = NSBezierPath()
            track.appendArc(withCenter: c, radius: r, startAngle: 0, endAngle: 360)
            track.lineWidth = lw
            NSColor.black.withAlphaComponent(0.28 * alpha).setStroke()
            track.stroke()

            let sweep = max(0.02, min(progress, 1)) * 360
            let arc = NSBezierPath()
            arc.appendArc(withCenter: c, radius: r, startAngle: 90, endAngle: 90 - sweep, clockwise: true)
            arc.lineWidth = lw
            arc.lineCapStyle = .round
            NSColor.black.withAlphaComponent(alpha).setStroke()
            arc.stroke()

            let dr = s * 0.12
            NSColor.black.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - dr, y: c.y - dr, width: dr * 2, height: dr * 2)).fill()
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Accessory apps get no default menu, so standard editing shortcuts (Cmd+V/C/X/A/Z)
    /// don't reach text fields. Install a minimal Edit menu to enable them.
    private func setupMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit LockedIn", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        NSApp.mainMenu = main
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // Activate first — for a Dock-less accessory app the first click otherwise just
        // activates the app and the transient popover dismisses itself, so it "misses".
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }
}
