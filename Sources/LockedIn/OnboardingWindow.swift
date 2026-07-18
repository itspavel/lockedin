import AppKit
import SwiftUI

/// First-run welcome. Shows once, explains the menu-bar model, and points to the
/// optional editor sensor + Claude usage connection.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private static let doneKey = "onboarding.shown"

    static var shouldShow: Bool { !UserDefaults.standard.bool(forKey: doneKey) }

    /// `onOpenSettings` opens the dashboard on the Settings tab (to connect Claude usage).
    func show(onOpenSettings: @escaping () -> Void) {
        let wasOpen = window?.isVisible ?? false
        if window == nil {
            let view = OnboardingView(
                onOpenSettings: { [weak self] in self?.finish(); onOpenSettings() },
                onFinish: { [weak self] in self?.finish() })
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)

            let w = NSWindow(contentRect: host.frame,
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.contentView = host
            w.center()
            w.delegate = self
            window = w
        }
        if !wasOpen { DockPolicy.windowOpened() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        DockPolicy.windowClosed()
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.doneKey)
        window?.close()
    }
}

struct OnboardingView: View {
    var onOpenSettings: () -> Void
    var onFinish: () -> Void

    private let steps: [(String, String, String)] = [
        ("menubar.rectangle", "It lives in your menu bar",
         "Look up at the top-right — that's your focused time, and clicking it opens the popover. No Dock icon, no window in the way."),
        ("wand.and.stars", "It tracks itself",
         "Open Cursor, VS Code, or Claude Code and just work. Time splits into you vs your agents automatically — nothing to start or stop."),
        ("keyboard", "Optional — editor sensor",
         "Install the Cursor/VS Code extension for a typed-vs-AI-generated breakdown. Run scripts/install-extension.sh from the repo."),
        ("gauge.with.dots.needle.50percent", "Optional — Claude usage",
         "Connect your claude.ai cookie to see session & weekly limits, plus how much API value your plan delivered."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome to LockedIn").font(.title2.weight(.bold))
                    Text("Zero-input time tracking for building with AI.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, s in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: s.0).font(.title3)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.1).font(.callout.weight(.semibold))
                            Text(s.2).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack {
                Button("Connect Claude usage…") { onOpenSettings() }
                Spacer()
                Button("Get started") { onFinish() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(CTAButtonStyle())
            }
            .padding(.top, 2)
        }
        .padding(26)
        .frame(width: 460)
        .background(Theme.background)
        .fontDesign(.monospaced)
        .environment(\.colorScheme, .dark)
        .tint(Theme.accent)
    }
}
