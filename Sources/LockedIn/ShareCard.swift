import SwiftUI

/// The achievement-poster share card. This is the growth loop — what lands on X.
struct ShareCard: View {
    let project: String
    let day: Int
    let human: TimeInterval
    let agent: TimeInterval
    let streak: Int
    let lifetime: TimeInterval
    let prompts: Int
    var tokens: Int = 0
    var cost: Double = 0

    private var total: TimeInterval { human + agent }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DAY \(day) — \(project.uppercased())")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)

            Text(total.hoursCompact)
                .font(.system(size: 64, weight: .black, design: .monospaced))

            Text("locked in · you \(human.hoursCompact) + agents \(agent.hoursCompact)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            SplitBar(human: human, agent: agent, height: 16)

            HStack(spacing: 10) {
                badge("flame", "\(streak)-day streak")
                badge("clock", "\(lifetime.hoursCompact) total")
                badge("cpu", "\(prompts) prompts")
            }
            if tokens > 0 {
                HStack(spacing: 10) {
                    badge("circle.hexagongrid", "\(tokens.tokensCompact) tokens")
                    badge("dollarsign.circle", "\(cost.usd) API value")
                }
            }

            HStack {
                Text("building in public").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("LockedIn").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }

    private func badge(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5))
    }
}

/// Sheet that previews the card and exports a 2x PNG to a temp file, then opens share.
struct ShareCardSheet: View {
    @ObservedObject var tracker: Tracker
    @Environment(\.dismiss) private var dismiss

    private var top: (name: String, time: ProjectTime)? { tracker.sortedProjects.first }

    var body: some View {
        let card = makeCard()
        VStack(spacing: 16) {
            card.padding(.top, 8)
            HStack {
                Button("Close") { dismiss() }
                Spacer()
                Button {
                    if let url = export(card) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                } label: { Label("Save PNG", systemImage: "square.and.arrow.down") }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
        .tint(Theme.accent)
    }

    private func makeCard() -> ShareCard {
        let name = top?.name ?? "your project"
        let t = top?.time ?? ProjectTime(human: tracker.today.humanTotal, agent: tracker.today.agentTotal)
        return ShareCard(
            project: name,
            day: max(tracker.streak, 1),
            human: t.human, agent: t.agent,
            streak: tracker.streak,
            lifetime: tracker.lifetime(of: name),
            prompts: tracker.today.prompts,
            tokens: tracker.today.tokenTotal.total,
            cost: tracker.today.costToday
        )
    }

    @MainActor private func export(_ card: ShareCard) -> URL? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LockedIn-\(DayLog.key()).png")
        try? png.write(to: url)
        return url
    }
}
