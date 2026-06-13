import SwiftUI

/// Design tokens. SF Symbols only — no emoji anywhere in the UI (user rule).
enum Theme {
    static let human = Color.primary
    static let agent = Color.secondary
    static let accent = Color.accentColor

    static let cardRadius: CGFloat = 16
    static let barHeight: CGFloat = 14
}

/// The signature element: one bar split into human (solid) and agent (hatched) portions.
struct SplitBar: View {
    let human: TimeInterval
    let agent: TimeInterval
    var height: CGFloat = Theme.barHeight

    private var total: TimeInterval { max(human + agent, 0.0001) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.human)
                    .frame(width: geo.size.width * human / total)
                Rectangle()
                    .fill(hatch)
                    .frame(width: geo.size.width * agent / total)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }

    /// Diagonal hatch fill that reads as "machine" against the solid human block.
    private var hatch: some ShapeStyle {
        .image(Self.hatchImage, scale: 1)
    }

    static let hatchImage: Image = {
        let size = NSSize(width: 6, height: 6)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.secondaryLabelColor.withAlphaComponent(0.55).setStroke()
        let p = NSBezierPath()
        p.lineWidth = 1.4
        p.move(to: NSPoint(x: -1, y: 5)); p.line(to: NSPoint(x: 5, y: -1))
        p.move(to: NSPoint(x: 1, y: 7)); p.line(to: NSPoint(x: 7, y: 1))
        p.stroke()
        img.unlockFocus()
        img.resizingMode = .tile
        return Image(nsImage: img)
    }()
}

struct LegendDot: View {
    let label: String
    let hatched: Bool
    var body: some View {
        HStack(spacing: 5) {
            Group {
                if hatched {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.agent.opacity(0.55))
                } else {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.human)
                }
            }
            .frame(width: 10, height: 10)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
