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
        LoginItem.reconcileAtLaunch()   // heal stale registrations (e.g. dev-build path)
        tracker.start()

        widget = WidgetWindowController(tracker: tracker)
        widget.restoreVisibility()
        dashboard = DashboardWindowController(tracker: tracker)
        widget.onOpenDashboard = { [weak self] in self?.dashboard.show() }

        StatusMonitor.shared.start()
        UsageManager.shared.start()
        Updater.shared.start()

        makeStatusItem()

        popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)   // console-brand content, dark chrome
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
        // Screenshot helper: pop the menu-bar popover shortly after launch.
        if CommandLine.arguments.contains("--popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.togglePopover() }
        }
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

    /// Relaunching from Finder/Spotlight opens the dashboard — the escape hatch when the
    /// menu-bar item is swallowed by a crowded bar/notch.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        dashboard.show()
        return true
    }

    /// True when the status item landed under the notch. Hidden items may get NO window
    /// at all — on a notched screen that absence is itself the signal.
    private func statusItemHiddenByNotch() -> Bool {
        guard let screen = NSScreen.main, screen.safeAreaInsets.top > 0 else { return false }
        guard let win = statusItem.button?.window, win.isVisible else { return true }
        let midX = win.frame.midX
        let inArea: (NSRect?) -> Bool = { area in
            guard let a = area else { return false }
            return midX >= a.minX && midX <= a.maxX
        }
        return !(inArea(screen.auxiliaryTopLeftArea) || inArea(screen.auxiliaryTopRightArea))
    }

    private var notchNotified = false
    private var notchHiddenStreak = 0
    private var notchRescueAttempts = 0

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "LockedIn"   // macOS keys the item's position on this
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        // Left-click = popover, right-click = quick menu (the Stats/Ice pattern).
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Right-click quick menu on the status item.
    private func showQuickMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Dashboard", action: #selector(menuOpenDashboard), keyEquivalent: "d").target = self
        menu.addItem(withTitle: widget.isVisible ? "Hide Desktop Widget" : "Show Desktop Widget",
                     action: #selector(menuToggleWidget), keyEquivalent: "w").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(menuOpenSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LockedIn", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil            // detach so left-click keeps opening the popover
    }

    @objc private func menuOpenDashboard() { dashboard.show() }
    @objc private func menuToggleWidget() { widget.toggle() }
    @objc private func menuOpenSettings() { dashboard.show(tab: .settings) }

    /// Notch rescue: removing and recreating the item re-inserts it at the front of the
    /// visible section (beside the notch) — the only reposition mechanism macOS allows.
    /// Debounced (two consecutive hidden checks, so launch races don't misfire) and
    /// retried up to 3 times; after that, icon-only.
    private func rescueFromNotch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            guard self.statusItemHiddenByNotch() else { self.notchHiddenStreak = 0; return }
            self.notchHiddenStreak += 1
            guard self.notchHiddenStreak >= 2 else { return }

            guard self.notchRescueAttempts < 3 else {
                self.statusItem.button?.title = ""
                if !self.notchNotified {
                    self.notchNotified = true
                    if !self.widget.isVisible { self.widget.show() }
                    Notifier.send("Your menu bar is full — LockedIn can't fit",
                                  "Stats stay on the desktop widget (tap it for the Dashboard), or launch LockedIn again from Spotlight. Freeing menu-bar space brings the item back.")
                }
                return
            }
            self.notchRescueAttempts += 1
            self.notchHiddenStreak = 0

            NSStatusBar.system.removeStatusItem(self.statusItem)
            self.makeStatusItem()
            self.refreshStatusItem()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !self.statusItemHiddenByNotch(), !self.notchNotified {
                    self.notchNotified = true
                    Notifier.send("LockedIn moved out from under the notch",
                                  "Your menu bar was crowded, so it relocated next to the notch. ⌘-drag to move it anywhere.")
                }
            }
        }
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        defer { rescueFromNotch() }

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
        // Your focused time today (midnight–midnight), plus the session usage % when
        // connected. Narrower styles exist because macOS hides menu-bar items that fall
        // under the notch on a crowded bar.
        switch tracker.menuBarStyle {
        case .iconOnly:
            button.title = ""
        case .timeOnly:
            button.title = " " + tracker.today.humanTotal.hoursCompact
        case .full:
            var title = " " + tracker.today.humanTotal.hoursCompact
            if UsageManager.shared.connected, let p = UsageManager.shared.session?.percent {
                title += " · \(Int(p))%"
            }
            button.title = title
        }
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

    /// Accessory apps get no menu — install Edit so Cmd+V/C/X/A/Z work in text fields.
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
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuickMenu()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // Activate first, or the first click only activates and the popover self-dismisses.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }
}
