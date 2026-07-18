import SwiftUI

/// Design tokens. SF Symbols only, no emoji. "Console" system shared with the website:
/// near-black terminal surfaces, one green accent, monospaced numerals, always dark.
/// Palette mirrors landing/src/app/globals.css — change both together.
enum Theme {
    // Surfaces (#10161c → #0a0e13; panels #0d1218, hairlines #1c232e)
    static let bgTop = Color(red: 0.063, green: 0.086, blue: 0.110)
    static let bgBottom = Color(red: 0.039, green: 0.055, blue: 0.075)
    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .topLeading, endPoint: .bottom)
    }
    static let card = Color(red: 0.051, green: 0.071, blue: 0.094)        // #0d1218
    static let cardBorder = Color(red: 0.110, green: 0.137, blue: 0.180)  // #1c232e

    // Accent — terminal green (#3FB950); CTAs get near-black-green text (#03210d).
    static let accent = Color(red: 0.247, green: 0.725, blue: 0.314)
    static let accentText = Color(red: 0.012, green: 0.129, blue: 0.051)

    // Data colors: "you" = solid green; agents = green hatch (see SplitBar).
    static let human = accent
    static let agent = accent.opacity(0.45)
    static let good = accent
    static let blue = Color(red: 0.290, green: 0.639, blue: 0.847)    // weekly (#4aa3d8)
    static let purple = Color(red: 0.788, green: 0.549, blue: 0.847)  // fable (#c98cd8)

    // Brand mark — the Ring Spark, in console green (matches the site's nav ring).
    static let brand = accent

    static let cardRadius: CGFloat = 16
    static let barHeight: CGFloat = 14
}

/// The brand mark — "Ring Spark": a progress ring frozen at 70% with a center dot.
struct BrandMark: View {
    var size: CGFloat = 16
    var color: Color = Theme.brand
    var progress: Double = 0.7

    var body: some View {
        // Ratios from the source SVG (viewBox 72: r 26, stroke 7, dot r 7).
        let stroke = size * (7 / 59)
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: stroke)
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
    /// system-light against the dark app.
    func brandPopover() -> some View {
        self.background(Theme.bgBottom).environment(\.colorScheme, .dark)
    }
}

/// The signature green pill CTA (dark text on terminal green).
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

/// The signature element: one bar split into human (solid green) and agent (green hatch),
/// exactly like the website's split bars.
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
                    .fill(Color(red: 0.247, green: 0.725, blue: 0.314).opacity(0.16))
                    .overlay(Rectangle().fill(hatch))
                    .frame(width: geo.size.width * agent / total)
            }
        }
        .frame(height: height)
        .background(Color(red: 0.086, green: 0.110, blue: 0.141))   // #161c24 track
        .clipShape(RoundedRectangle(cornerRadius: height / 3, style: .continuous))
    }

    private var hatch: some ShapeStyle {
        .image(Self.hatchImage, scale: 1)
    }

    /// Green diagonal stripes — the website's agent texture.
    static let hatchImage: Image = {
        let size = NSSize(width: 7, height: 7)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor(red: 0.247, green: 0.725, blue: 0.314, alpha: 0.85).setStroke()
        let p = NSBezierPath()
        p.lineWidth = 1.6
        p.move(to: NSPoint(x: -1, y: 6)); p.line(to: NSPoint(x: 6, y: -1))
        p.move(to: NSPoint(x: 1, y: 8)); p.line(to: NSPoint(x: 8, y: 1))
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
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accent.opacity(0.16))
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .fill(ImagePaint(image: SplitBar.hatchImage, scale: 1)))
                } else {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.human)
                }
            }
            .frame(width: 10, height: 10)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
