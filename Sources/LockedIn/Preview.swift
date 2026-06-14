import SwiftUI
import AppKit

/// Headless render mode: `LockedIn --render <dir>` dumps PNGs of the real UI
/// (popover + share card) using current data, then exits. Our "Xcode preview"
/// without Xcode — works on any macOS, no Simulator, no canvas.
@MainActor
enum Preview {
    static func render(to dir: String) {
        let tracker = Tracker()
        seedIfEmpty(tracker)

        let outDir = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        dump(PopoverView(tracker: tracker).frame(width: 320), to: outDir.appendingPathComponent("popover.png"))

        let top = tracker.sortedProjects.first
        let card = ShareCard(
            project: top?.name ?? "your project",
            day: max(tracker.streak, 1),
            human: top?.time.human ?? tracker.today.humanTotal,
            agent: top?.time.agent ?? tracker.today.agentTotal,
            streak: tracker.streak,
            lifetime: tracker.lifetime(of: top?.name ?? ""),
            prompts: tracker.today.prompts,
            tokens: tracker.today.tokenTotal.total,
            cost: tracker.today.costToday
        )
        dump(card, to: outDir.appendingPathComponent("sharecard.png"))

        // Desktop widget at each size, on a dark backdrop to mimic the frosted panel.
        for s in WidgetSize.allCases {
            tracker.setWidgetSize(s)
            let w = DesktopWidgetView(tracker: tracker)
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            dump(w, to: outDir.appendingPathComponent("widget-\(s.rawValue).png"))
        }

        print("rendered to \(dir)")
        exit(0)
    }

    private static func dump<V: View>(_ view: V, to url: URL) {
        let renderer = ImageRenderer(content: view.padding(18).background(Color(nsColor: .windowBackgroundColor)))
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    /// If there's no real data yet, seed a believable day so the preview looks alive.
    private static func seedIfEmpty(_ tracker: Tracker) {
        guard tracker.today.total == 0 else { return }
        tracker.seedSample()
    }
}
