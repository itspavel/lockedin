import SwiftUI

/// Design tokens. SF Symbols only — no emoji anywhere in the UI (user rule).
/// Utility-app palette (CleanMyMac-inspired, approved 2026-07-14): deep violet gradient
/// surfaces, soft white-on-purple cards, one warm yellow accent for CTAs and hero data.
/// Everything renders in forced dark scheme — the purple IS the brand surface.
enum Theme {
    // Surfaces
    static let bgTop = Color(red: 0.216, green: 0.145, blue: 0.400)     // deep violet
    static let bgBottom = Color(red: 0.106, green: 0.067, blue: 0.212)  // near-black purple
    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .topLeading, endPoint: .bottom)
    }
    static let card = Color.white.opacity(0.07)
    static let cardBorder = Color.white.opacity(0.09)

    // Accent — warm yellow; CTAs get dark text on it.
    static let accent = Color(red: 1.0, green: 0.83, blue: 0.29)
    static let accentText = Color(red: 0.18, green: 0.12, blue: 0.02)

    // Data colors: "you" is the hero (yellow), agents stay quiet hatched light.
    static let human = accent
    static let agent = Color.white.opacity(0.45)
    static let good = Color(red: 0.35, green: 0.85, blue: 0.48)

    // Brand mark coral (design "Widget Logo Options" option 1a — Ring Spark).
    static let brand = Color(red: 232 / 255, green: 130 / 255, blue: 90 / 255)

    static let cardRadius: CGFloat = 16
    static let barHeight: CGFloat = 14
}

/// The brand mark — design option 1a "Ring Spark": a progress ring frozen at 70% with a
/// center dot ("reads as session % instantly at any size"). Coral on any surface.
struct BrandMark: View {
    var size: CGFloat = 16
    var color: Color = Theme.brand
    var progress: Double = 0.7

    var body: some View {
        // Ratios from the source SVG (viewBox 72: r 26, stroke 7, dot r 7).
        let stroke = size * (7 / 59)
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: stroke)
            Circle().trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(color)
                .frame(width: size * (14 / 59), height: size * (14 / 59))
        }
        .padding(stroke / 2)
        .frame(width: size, height: size)
    }
}

extension View {
    /// Force a hover/help popover onto the dark brand surface so it doesn't render
    /// system-light against the purple app.
    func brandPopover() -> some View {
        self.background(Theme.bgBottom).environment(\.colorScheme, .dark)
    }
}

/// The signature yellow pill CTA (dark text on warm yellow).
struct CTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.bold))
            .foregroundStyle(Theme.accentText)
            .padding(.vertical, 9).padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1)))
    }
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
