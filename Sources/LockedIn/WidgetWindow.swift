import AppKit
import SwiftUI
import Combine

/// A draggable desktop widget. Borderless non-activating panel so it never steals focus
/// and shows on every Space. By default it sits ON the desktop, behind your apps; pin it
/// to float above everything. This is the "widget on the desktop" without WidgetKit (so:
/// no Xcode required).
@MainActor
final class WidgetWindowController {
    private let panel: NSPanel
    private let posKey = "widget.frameOrigin"
    private let visKey = "widget.visible"
    private var pinCancellable: AnyCancellable?

    init(tracker: Tracker) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        // Rounded clipping container — this is what actually rounds the corners
        // (an NSVisualEffectView's own layer.cornerRadius leaves sharp edges).
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false

        let host = NSHostingView(rootView: DesktopWidgetView(tracker: tracker))
        host.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(blur)
        blur.addSubview(host)
        panel.contentView = container

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            blur.topAnchor.constraint(equalTo: container.topAnchor),
            blur.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            host.topAnchor.constraint(equalTo: blur.topAnchor),
            host.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])

        // Size the panel to the SwiftUI content (guard against a zero pre-layout size).
        host.layoutSubtreeIfNeeded()
        let fit = host.fittingSize
        let size = NSSize(width: fit.width > 0 ? fit.width : 240,
                          height: fit.height > 0 ? fit.height : 210)
        panel.setContentSize(size)
        restorePosition()

        // Apply the pinned level now and whenever it changes.
        applyLevel(pinned: tracker.widgetPinned)
        pinCancellable = tracker.$widgetPinned.sink { [weak self] pinned in
            self?.applyLevel(pinned: pinned)
        }
    }

    /// Pinned → floats above all windows. Unpinned → sits on the desktop, behind apps.
    private func applyLevel(pinned: Bool) {
        if pinned {
            panel.level = .floating
        } else {
            // Just above the desktop/wallpaper but below normal app windows.
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        }
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        panel.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: visKey)
    }

    func hide() {
        savePosition()
        panel.orderOut(nil)
        UserDefaults.standard.set(false, forKey: visKey)
    }

    func toggle() { isVisible ? hide() : show() }

    /// Show on launch only if the user had it visible last time (default: show).
    func restoreVisibility() {
        let wantVisible = UserDefaults.standard.object(forKey: visKey) as? Bool ?? true
        if wantVisible { show() }
    }

    func savePosition() {
        let o = panel.frame.origin
        UserDefaults.standard.set(["x": o.x, "y": o.y], forKey: posKey)
    }

    private func restorePosition() {
        if let dict = UserDefaults.standard.dictionary(forKey: posKey),
           let x = dict["x"] as? CGFloat, let y = dict["y"] as? CGFloat {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            // Default: top-right, under the menu bar.
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.maxX - panel.frame.width - 24,
                                         y: f.maxY - panel.frame.height - 24))
        }
    }
}
