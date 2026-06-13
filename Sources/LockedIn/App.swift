import SwiftUI
import AppKit

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
    private var cancellable: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        tracker.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 460)
        popover.contentViewController = NSHostingController(rootView: PopoverView(tracker: tracker))

        // Repaint the menu bar label on every tracker change.
        cancellable = tracker.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.refreshStatusItem() }
        }
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }

        if let lock = tracker.lockSession {
            button.image = symbol("lock.fill")
            button.title = " " + lock.remaining.countdown
            return
        }

        let agentRunning = !tracker.activeAgents.isEmpty
        let name = agentRunning ? "gearshape.2.fill"
                 : tracker.humanActiveNow ? "circle.fill" : "circle"
        button.image = symbol(name)
        button.title = " " + tracker.today.total.clockCompact
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
