import AppKit
import SwiftUI
import Combine

/// A draggable desktop widget. Borderless non-activating panel so it never steals focus
/// and shows on every Space. By default it sits behind your apps; pin it to float above
/// everything. The "widget on the desktop" without WidgetKit (so: no Xcode required).
///
/// Dragging is done with a SwiftUI gesture (minimumDistance), NOT
/// isMovableByWindowBackground — the latter swallows button taps (pin/pause/stop).
@MainActor
final class WidgetWindowController {
    private let panel: NSPanel
    private let tracker: Tracker
    private let posKey = "widget.frameOrigin"
    private let visKey = "widget.visible"
    private var cancellables = Set<AnyCancellable>()
    private var dragStartMouse: NSPoint?
    private var dragStartOrigin: NSPoint?

    init(tracker: Tracker) {
        self.tracker = tracker
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: tracker.widgetSize.width, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false   // we drag via gesture instead
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        buildContent()
        sizeToContent()
        restorePosition()

        applyLevel(pinned: tracker.widgetPinned)
        tracker.$widgetPinned.sink { [weak self] in self?.applyLevel(pinned: $0) }.store(in: &cancellables)
        // Resize when the size preset changes.
        tracker.$widgetSize.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.sizeToContent() }
        }.store(in: &cancellables)
    }

    private func buildContent() {
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

        let root = DesktopWidgetView(
            tracker: tracker,
            onDrag: { [weak self] in self?.drag() },
            onDragEnd: { [weak self] in self?.endDrag() }
        )
        let host = NSHostingView(rootView: root)
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
    }

    private func sizeToContent() {
        // Measure with a fresh, UNCONSTRAINED hosting view. The live host is pinned to fill
        // the window by Auto Layout, so its fittingSize just echoes the current width and the
        // window never grows. A throwaway view reports the SwiftUI content's true ideal size.
        let measure = NSHostingView(rootView: DesktopWidgetView(tracker: tracker))
        measure.layoutSubtreeIfNeeded()
        let fit = measure.fittingSize
        let size = NSSize(width: fit.width > 0 ? fit.width : tracker.widgetSize.width,
                          height: fit.height > 0 ? fit.height : 210)
        // Keep the top-left corner anchored as it grows/shrinks.
        let top = panel.frame.maxY
        panel.setContentSize(size)
        panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top))
    }

    // MARK: - Drag (gesture-driven)

    /// Move the window by tracking the absolute screen mouse position. Stable because the
    /// reference (NSEvent.mouseLocation) doesn't move with the window — no feedback, no lag.
    private func drag() {
        let mouse = NSEvent.mouseLocation
        if dragStartMouse == nil { dragStartMouse = mouse; dragStartOrigin = panel.frame.origin }
        guard let sm = dragStartMouse, let so = dragStartOrigin else { return }
        panel.setFrameOrigin(NSPoint(x: so.x + (mouse.x - sm.x), y: so.y + (mouse.y - sm.y)))
    }

    private func endDrag() { dragStartMouse = nil; dragStartOrigin = nil; savePosition() }

    // MARK: - Level / visibility

    private func applyLevel(pinned: Bool) {
        // Pinned: float above every app. Unpinned: sit on the desktop, behind all app
        // windows (just above the wallpaper). isFloatingPanel must also toggle off, or the
        // panel keeps floating above other apps regardless of the level we set.
        panel.isFloatingPanel = pinned
        panel.level = pinned
            ? .floating
            : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        if panel.isVisible { panel.orderFrontRegardless() }
    }

    var isVisible: Bool { panel.isVisible }
    func show() { panel.orderFrontRegardless(); UserDefaults.standard.set(true, forKey: visKey) }
    func hide() { savePosition(); panel.orderOut(nil); UserDefaults.standard.set(false, forKey: visKey) }
    func toggle() { isVisible ? hide() : show() }

    func restoreVisibility() {
        let want = UserDefaults.standard.object(forKey: visKey) as? Bool ?? true
        if want { show() }
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
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.maxX - panel.frame.width - 24,
                                         y: f.maxY - panel.frame.height - 24))
        }
    }
}
