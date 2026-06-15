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
        return VStack(alignment: .leading, spacing: size == .small ? 7 : 10) {
            header
            ForEach(tracker.widgetConfig.components) { comp in
                component(comp, d)
            }
            if d.total == 0 && tracker.activeSessions.isEmpty {
                Text("Start coding. This fills itself.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    /// How many projects the list shows, by width.
    private var projectLimit: Int {
        switch size { case .small: 1; case .medium: 2; case .large: 3; case .xlarge: 5 }
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
            if !tracker.activeSessions.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape.2").font(.caption2)
                    Text(tracker.totalAgentCount > 1 ? "\(tracker.totalAgentCount) agents working"
                                                     : "Agent on \(tracker.activeSessions.first?.projectName ?? "")")
                        .lineLimit(1).truncationMode(.middle)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        case .tokens:
            if d.tokenTotal.total > 0 {
                HStack(spacing: 6) {
                    toolGlyph
                    Text("\(d.tokenTotal.total.tokensCompact) tokens")
                    Text("·").foregroundStyle(.tertiary)
                    Text(d.costToday.usd).fontWeight(.semibold)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        case .keystrokes:
            if tracker.editorKeystrokes > 0 || tracker.editorGenerated > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard").font(.caption2)
                    Text("\(tracker.editorKeystrokes) typed")
                    if tracker.editorGenerated > 0 {
                        Text("· \(tracker.editorGenerated) AI").foregroundStyle(.tertiary)
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        case .streak:
            HStack(spacing: 14) {
                if tracker.streak > 0 { Label("\(tracker.streak)d", systemImage: "flame") }
                Label("\(d.prompts)", systemImage: "cpu").help("prompts today")
            }
            .font(.caption2).foregroundStyle(.secondary)
        case .usage:
            if usage.connected {
                VStack(alignment: .leading, spacing: 4) {
                    usageBar("Session", usage.session?.percent)
                    if size != .small { usageBar("Weekly", usage.weekly?.percent) }
                    if let r = usage.session?.resetsAt {
                        Text("Session resets \(r.untilCompact)")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func usageBar(_ label: String, _ pct: Double?) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
            ProgressView(value: min((pct ?? 0) / 100, 1)).frame(maxWidth: 90)
            Text("\(Int(pct ?? 0))%").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
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
                    .foregroundStyle(tracker.widgetPinned ? Color.accentColor : .secondary)
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
