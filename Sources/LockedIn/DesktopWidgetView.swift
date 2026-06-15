import SwiftUI

/// The always-on-desktop widget. Three sizes (S/M/L) show progressively more detail.
/// Dragging is a gesture passed up to the window controller (so button taps still work).
struct DesktopWidgetView: View {
    @ObservedObject var tracker: Tracker
    @ObservedObject private var usage = UsageManager.shared
    var onDrag: () -> Void = {}
    var onDragEnd: () -> Void = {}

    private var size: WidgetSize { tracker.widgetSize }

    var body: some View {
        Group {
            if tracker.lockActive { lockedFace } else { passiveFace }
        }
        .frame(width: size.width)
        .tint(Theme.accent)
        .contentShape(Rectangle())
        .gesture(
            // We ignore the translation and let the controller move the window using the
            // absolute mouse position — translation is measured in a frame that moves with
            // the window, which feeds back and lags (worse on larger sizes).
            DragGesture(minimumDistance: 6, coordinateSpace: .global)
                .onChanged { _ in onDrag() }
                .onEnded { _ in onDragEnd() }
        )
    }

    // MARK: - Passive (config-driven: renders only the components the user picked)

    private var passiveFace: some View {
        let d = tracker.today
        return VStack(alignment: .leading, spacing: size == .small ? 9 : 13) {
            header
            ForEach(Array(visibleSections(d).enumerated()), id: \.offset) { _, sec in
                if let h = sec.header {
                    Divider().opacity(0.35)
                    if size != .small {
                        Text(h.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1.3)
                            .foregroundStyle(.tertiary)
                    }
                }
                VStack(alignment: .leading, spacing: size == .small ? 7 : 9) {
                    ForEach(sec.comps, id: \.self) { component($0, d) }
                }
            }
            if d.total == 0 && tracker.activeSessions.isEmpty {
                Text("Start coding. This fills itself.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(size == .small ? 15 : 18)
    }

    /// Logical groups, in order. Components keep their on/off from config; here we just
    /// arrange the enabled-and-non-empty ones into sections so the widget reads as blocks.
    private func visibleSections(_ d: DayLog) -> [(header: String?, comps: [WidgetComponent])] {
        let groups: [(String?, [WidgetComponent])] = [
            (nil, [.total, .split, .projects, .agents]),
            ("Today's work", [.tokens, .keystrokes, .streak]),
            ("Claude limits", [.usage]),
        ]
        return groups.compactMap { header, comps in
            let on = comps.filter { tracker.widgetConfig.isOn($0) && hasContent($0, d) }
            return on.isEmpty ? nil : (header, on)
        }
    }

    /// Whether a component actually has something to show right now (avoids empty rows
    /// and orphan section headers).
    private func hasContent(_ c: WidgetComponent, _ d: DayLog) -> Bool {
        switch c {
        case .total, .split, .projects, .streak: true
        case .agents: !tracker.activeSessions.isEmpty
        case .tokens: d.tokenTotal.total > 0
        case .keystrokes: tracker.editorKeystrokes > 0 || tracker.editorGenerated > 0
        case .usage: usage.connected
        }
    }

    /// How many projects the list shows, by width.
    private var projectLimit: Int {
        switch size { case .small: 1; case .medium: 2; case .large: 3; case .xlarge: 5 }
    }

    /// A leading icon in a fixed-width cell so all meta rows line up.
    private func iconCell(_ system: String) -> some View {
        Image(systemName: system).font(.caption2).foregroundStyle(.secondary)
            .frame(width: 16, alignment: .center)
    }

    @ViewBuilder private func component(_ c: WidgetComponent, _ d: DayLog) -> some View {
        switch c {
        case .total:
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(d.humanTotal.hoursCompact)
                    .font(.system(size: size == .small ? 34 : 44, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("focused").font(size == .small ? .caption : .callout).foregroundStyle(.secondary)
            }
        case .split:
            VStack(alignment: .leading, spacing: 6) {
                SplitBar(human: d.humanTotal, agent: d.agentTotal, height: size == .small ? 10 : 12)
                if size != .small {
                    HStack(spacing: 14) {
                        LegendDot(label: "You \(d.humanTotal.hoursCompact)", hatched: false)
                        LegendDot(label: "Agents \(d.agentTotal.hoursCompact)", hatched: true)
                    }
                }
            }
        case .projects:
            if tracker.widgetConfig.combineProjects {
                projectRow("All projects", d.total)
            } else {
                ForEach(tracker.sortedProjects.prefix(projectLimit), id: \.name) { p in
                    projectRow(p.name, p.time.total)
                }
            }
        case .agents:
            HStack(spacing: 8) {
                iconCell("gearshape.2")
                Text(tracker.totalAgentCount > 1 ? "\(tracker.totalAgentCount) agents working"
                                                 : "Agent on \(tracker.activeSessions.first?.projectName ?? "")")
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .font(.caption2).foregroundStyle(.secondary)
        case .tokens:
            HStack(spacing: 8) {
                toolGlyph.frame(width: 16)
                Text("\(d.tokenTotal.total.tokensCompact) tokens")
                Spacer(minLength: 4)
                Text(d.costToday.usd).fontWeight(.semibold).foregroundStyle(.primary.opacity(0.8))
            }
            .font(.caption2).foregroundStyle(.secondary)
        case .keystrokes:
            HStack(spacing: 8) {
                iconCell("keyboard")
                Text("\(tracker.editorKeystrokes.tokensCompact) typed")
                if tracker.editorGenerated > 0 {
                    Text("· \(tracker.editorGenerated.tokensCompact) AI").foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .font(.caption2).foregroundStyle(.secondary)
        case .streak:
            HStack(spacing: 16) {
                HStack(spacing: 8) { iconCell("flame"); Text("\(tracker.streak)d streak") }
                HStack(spacing: 8) { iconCell("cpu"); Text("\(d.prompts) prompts") }
                Spacer(minLength: 0)
            }
            .font(.caption2).foregroundStyle(.secondary)
        case .usage:
            VStack(alignment: .leading, spacing: size == .small ? 6 : 9) {
                usageBar("Session", usage.session)
                if size != .small { usageBar("Weekly", usage.weekly) }
                if let r = usage.session?.resetsAt {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 8, weight: .semibold))
                        Text("Session resets \(r.untilCompact)")
                    }
                    .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// A refined limit bar: label, a colored capsule that warns as it fills, and the %.
    private func usageBar(_ label: String, _ w: UsageWindow?) -> some View {
        let pct = w?.percent ?? 0
        let fill: Color = pct >= 90 ? .red : pct >= 70 ? .orange : Theme.accent
        return HStack(spacing: 9) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(fill.opacity(pct >= 70 ? 0.9 : 0.8))
                        .frame(width: max(7, geo.size.width * min(pct / 100, 1)))
                }
            }
            .frame(height: 7)
            Text("\(Int(pct))%").font(.caption.weight(.bold)).monospacedDigit()
                .foregroundStyle(pct >= 90 ? .red : .primary.opacity(0.85))
                .frame(width: 38, alignment: .trailing)
        }
    }

    private func projectRow(_ name: String, _ time: TimeInterval) -> some View {
        HStack {
            Text(name).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(time.hoursCompact).font(.callout.weight(.bold)).monospacedDigit()
        }
    }

    // MARK: - Locked

    private var lockedFace: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill").font(.caption)
                Text(tracker.lockProject ?? "Focus").font(.caption.weight(.bold)).lineLimit(1)
                Spacer()
                controls
            }
            Text(tracker.lockRemaining.countdown)
                .font(.system(size: size == .small ? 36 : 44, weight: .heavy, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText())
                .opacity(tracker.lockPaused ? 0.5 : 1)
            Text(tracker.lockPaused ? "paused" : "locked in")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                widgetControl(tracker.lockPaused ? "play.fill" : "pause.fill") { tracker.togglePauseLock() }
                widgetControl("stop.fill") { tracker.endLock(completed: false) }
            }
            .padding(.top, 2)
        }
        .padding(16)
    }

    // MARK: - Header / controls

    /// The real app icon of the current tool, grayscaled (real logo, not colourful).
    /// Falls back to a generic SF Symbol when we can't identify an installed app.
    @ViewBuilder private var toolGlyph: some View {
        if let icon = ToolIcon.icon(for: tracker.currentTool) {
            Image(nsImage: icon)
                .resizable().interpolation(.high)
                .frame(width: 13, height: 13)
                .grayscale(1).opacity(0.9)
        } else {
            Image(systemName: "circle.hexagongrid")
        }
    }

    private var header: some View {
        HStack {
            Text("TODAY").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            Spacer()
            if tracker.editorConnected || !tracker.activeSessions.isEmpty || tracker.humanActiveNow {
                Circle().fill(.green).frame(width: 7, height: 7)
            }
            controls
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button { cycleSize() } label: {
                Text(size.label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).help("Cycle widget size (S/M/L)")

            Button { tracker.toggleWidgetPin() } label: {
                Image(systemName: tracker.widgetPinned ? "pin.fill" : "pin")
                    .font(.caption2)
                    .foregroundStyle(tracker.widgetPinned ? Theme.accent : .secondary)
            }
            .buttonStyle(.plain)
            .help(tracker.widgetPinned ? "Pinned above apps — click to send behind"
                                       : "Behind apps — click to pin on top")
        }
    }

    private func cycleSize() {
        let all = WidgetSize.allCases
        let next = all[(all.firstIndex(of: size)! + 1) % all.count]
        tracker.setWidgetSize(next)
    }

    private func widgetControl(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.caption)
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}
