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
        Notifier.setup()                // request notification permission + delegates
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

    /// The window server's own answer to "is our item actually drawn?".
    ///
    /// `NSWindow.isVisible` is not that answer — it stays true even when the bar has no
    /// room and macOS quietly declines to display the item (its window then simply isn't
    /// in the on-screen list). Returns nil while the entire menu bar is hidden
    /// (full-screen app, lock screen, Space change), where the question is meaningless
    /// and acting on it caused false rescues.
    /// Asks the window server whether our item is actually being drawn, and how much room
    /// the right-of-notch region gives it.
    ///
    /// Both halves are easy to get wrong. Menu-bar windows exist for *every* display and for
    /// the app menus left of the notch, so the neighbour scan has to be confined to this
    /// screen and to x >= the region start — otherwise the left-hand app menus (x≈60) win the
    /// `min` and the room comes out negative, which silently disables growing back. And our
    /// own item gets one window per display, so identify it by PID rather than by the single
    /// `windowNumber` AppKit hands us.
    /// The display whose geometry this logic is about: the notched built-in one. `NSScreen.main`
    /// follows keyboard focus, so on a second monitor it measures the wrong bar entirely.
    private var barScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func statusItemOnScreen() -> (onScreen: Bool, neighbourEdge: CGFloat)? {
        guard let screen = barScreen else { return nil }
        let regionStart = screen.auxiliaryTopRightArea?.minX ?? screen.frame.minX
        let screenRight = screen.frame.maxX
        let screenLeft = screen.frame.minX
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let ourPID = Int(ProcessInfo.processInfo.processIdentifier)

        var barVisible = false
        var itemVisible = false
        var ourRight: CGFloat?
        var leftmostForeign = CGFloat.greatestFiniteMagnitude

        for w in list {
            guard let b = w["kCGWindowBounds"] as? [String: Any],
                  let y = b["Y"] as? Double, y < 2,
                  let h = b["Height"] as? Double, h < 45,
                  let x = b["X"] as? Double, let width = b["Width"] as? Double,
                  x >= screenLeft, x < screenRight   // the notched display only
            else { continue }

            if let pid = w["kCGWindowOwnerPID"] as? Int, pid == ourPID {
                itemVisible = true
                barVisible = true
                ourRight = max(ourRight ?? 0, CGFloat(x + width))
                continue
            }
            if let owner = w["kCGWindowOwnerName"] as? String,
               owner == "Control Center" || owner == "ControlCenter" || owner == "SystemUIServer" {
                barVisible = true
            }
            if CGFloat(x) >= regionStart { leftmostForeign = min(leftmostForeign, CGFloat(x)) }
        }
        guard barVisible else { return nil }

        // Drawn: our own right edge bounds the slot we can grow into. Hidden: the nearest
        // item that took the space we'd occupy.
        let edge = ourRight ?? min(leftmostForeign, screenRight)
        return (itemVisible, edge)
    }

    /// The label ladder. Your focused time today plus the live session %; when the bar
    /// runs out of room we tighten the spelling before giving anything up, because the
    /// percentage is worth more than the punctuation between them.
    ///   0  ◍ " 4h 12m · 92%"   1  ◍ " 4h12m 92%"   2  "4h12m 92%" (no icon — the ring
    ///   costs ~26pt, more than the percentage does)   3  ◍ " 4h 12m"   4  icon only
    private func menuBarLabel(level: Int) -> String {
        let time = tracker.today.humanTotal.hoursCompact
        let pct = UsageManager.shared.connected ? UsageManager.shared.session?.percent : nil
        let tight = time.replacingOccurrences(of: " ", with: "")
        switch level {
        case 0:
            guard let p = pct else { return " " + time }
            return " \(time) · \(Int(p))%"
        case 1:
            guard let p = pct else { return " " + time }
            return " \(tight) \(Int(p))%"
        case 2:
            guard let p = pct else { return " " + time }
            return "\(tight) \(Int(p))%"
        case 3:
            return " " + time
        default:
            return ""
        }
    }

    /// Level 2 drops the ring so the numbers survive — only offered to people who asked
    /// for that trade in Settings.
    private func levelHidesIcon(_ level: Int) -> Bool { level == 2 && tracker.preferPercentOverIcon }

    /// The richest label the user actually asked for — the ceiling fitLevel trims below.
    private var configuredLevel: Int {
        switch tracker.menuBarStyle {
        case .full: return 0
        case .timeOnly: return 3
        case .iconOnly: return 4
        }
    }

    /// Roughly what the ring image plus its spacing adds to the item.
    private let iconAllowance: CGFloat = 26

    private func labelWidth(_ s: String) -> CGFloat {
        let font = statusItem.button?.font ?? NSFont.menuBarFont(ofSize: 0)
        return (s as NSString).size(withAttributes: [.font: font]).width
    }

    private func preferredLabelWidth() -> CGFloat {
        labelWidth(menuBarLabel(level: configuredLevel))
    }

    /// Room our item can occupy: everything from the start of the usable region up to
    /// the neighbour it butts against. macOS lays items out right-to-left, so this is
    /// the number that decides whether we get drawn at all.
    private func availableWidth(neighbourEdge: CGFloat) -> CGFloat {
        let regionStart = barScreen?.auxiliaryTopRightArea?.minX ?? barScreen?.frame.minX ?? 0
        return neighbourEdge - regionStart
    }

    /// Growing the label back is only worth a try when something actually changed:
    /// the bar's contents shifted (an app quit, a Space switched), or the label itself
    /// got shorter than the one that didn't fit (a new day, a smaller percentage).
    /// A plain timer here makes the item vanish for a few seconds on every retry.
    private func worthRetryingFullLabel(neighbourEdge: CGFloat) -> Bool {
        if let room = failedAvailableWidth, availableWidth(neighbourEdge: neighbourEdge) > room + 4 { return true }
        if let w = failedLabelWidth, preferredLabelWidth() < w - 4 { return true }
        return false
    }

    private var notchNotified = false
    private var notchHiddenStreak = 0
    private var notchRescueAttempts = 0
    /// How much the label has been trimmed to stay on the bar: 0 = as configured,
    /// 1 = drop the usage %, 2 = icon only.
    private var fitLevel = 0
    private var lastFitCheck = Date.distantPast
    private var lastFitCrumb = ""
    private var itemCreatedAt = Date.distantPast
    private var missStreak = 0
    /// What the bar looked like when the label last failed to fit.
    private var failedLabelWidth: CGFloat?
    private var failedAvailableWidth: CGFloat?

    private func makeStatusItem() {
        itemCreatedAt = Date()      // macOS needs a moment to place it; don't judge before then
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "LockedIn"   // macOS keys the item's position on this
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.imageHugsTitle = true   // reclaims the padding between ring and label
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

    /// Keeps the item on a crowded bar by shrinking what it says rather than vanishing.
    ///
    /// The label grows through the day ("45m" → "4h 12m · 92%"), and macOS silently hides
    /// menu-bar items that no longer fit — so this closes a loop on *observed* visibility:
    /// hidden → drop a component (usage %, then the time); genuinely out of room even as a
    /// bare icon → the remove/recreate notch rescue; visible again → occasionally try to
    /// grow back, in case the bar freed up. Checks are throttled: the window-list scan is
    /// far too expensive to run on every tracker tick.
    private func checkStatusItemFit() {
        guard Date().timeIntervalSince(lastFitCheck) >= 8 else { return }
        // A freshly created item isn't in the window list for a second or two; judging it
        // that early reads as "hidden" and shrinks a label that had room all along.
        guard Date().timeIntervalSince(itemCreatedAt) >= 6 else { return }
        lastFitCheck = Date()

        guard let state = statusItemOnScreen() else { return }   // bar hidden — no signal
        let crumb = "level=\(fitLevel) onScreen=\(state.onScreen) "
            + "avail=\(Int(availableWidth(neighbourEdge: state.neighbourEdge))) "
            + "failedAvail=\(failedAvailableWidth.map { String(Int($0)) } ?? "-") "
            + "failedLabel=\(failedLabelWidth.map { String(Int($0)) } ?? "-") "
            + "want=\(Int(preferredLabelWidth())) title=\(statusItem.button?.title ?? "-")"
        if crumb != lastFitCrumb {
            lastFitCrumb = crumb
            UserDefaults.standard.set(crumb, forKey: "menubar.debug.fit")
        }

        if state.onScreen {
            notchHiddenStreak = 0
            notchRescueAttempts = 0
            missStreak = 0
            if fitLevel > 0, worthRetryingFullLabel(neighbourEdge: state.neighbourEdge) {
                fitLevel -= 1
                failedLabelWidth = nil
                failedAvailableWidth = nil
                refreshStatusItem()
            }
            return
        }

        // One miss can just be a transient re-layout; act on the second in a row.
        missStreak += 1
        guard missStreak >= 2 else { return }
        missStreak = 0

        // Shrink first: a narrower item is the only thing that actually wins back space.
        if fitLevel < 4 {
            // Step to the next level that is genuinely narrower — with no usage % to show,
            // "full" and "compact" render identically and stepping through them is a no-op
            // that costs the user their time display for nothing.
            let current = labelWidth(menuBarLabel(level: max(configuredLevel, fitLevel)))
                + (levelHidesIcon(max(configuredLevel, fitLevel)) ? 0 : iconAllowance)
            var next = fitLevel
            while next < 4 {
                next += 1
                let lvl = max(configuredLevel, next)
                // The icon-less rung only exists for people who'd rather lose the ring
                // than the percentage; otherwise step straight past it.
                if levelHidesIcon(lvl), !tracker.preferPercentOverIcon { continue }
                let w = labelWidth(menuBarLabel(level: lvl)) + (levelHidesIcon(lvl) ? 0 : iconAllowance)
                if w < current - 1 { break }
            }
            fitLevel = next
            failedLabelWidth = preferredLabelWidth()
            failedAvailableWidth = availableWidth(neighbourEdge: state.neighbourEdge)
            refreshStatusItem()
            // Re-place it at the narrower width; macOS won't re-lay-out a hidden item.
            NSStatusBar.system.removeStatusItem(statusItem)
            makeStatusItem()
            refreshStatusItem()
            return
        }

        notchHiddenStreak += 1
        guard notchHiddenStreak >= 2 else { return }

        guard notchRescueAttempts < 3 else {
            if !notchNotified {
                notchNotified = true
                if !widget.isVisible { widget.show() }
                Notifier.send("Your menu bar is full — LockedIn can't fit",
                              "Stats stay on the desktop widget (tap it for the Dashboard), or launch LockedIn again from Spotlight. Freeing menu-bar space brings the item back.")
            }
            return
        }
        notchRescueAttempts += 1
        notchHiddenStreak = 0

        NSStatusBar.system.removeStatusItem(statusItem)
        makeStatusItem()
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        defer { checkStatusItemFit() }

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
        var level = max(configuredLevel, fitLevel)
        if level == 2, !tracker.preferPercentOverIcon { level = 3 }   // keep the ring instead
        if levelHidesIcon(level) { button.image = nil }
        button.title = menuBarLabel(level: level)
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
