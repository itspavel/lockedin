import SwiftUI

/// The always-on-desktop widget. Three sizes (S/M/L) show progressively more detail.
/// Dragging is a gesture passed up to the window controller (so button taps still work).
struct DesktopWidgetView: View {
    @ObservedObject var tracker: Tracker
    var onDrag: (CGSize) -> Void = { _ in }
    var onDragEnd: () -> Void = {}

    private var size: WidgetSize { tracker.widgetSize }

    var body: some View {
        Group {
            if tracker.lockActive { lockedFace } else { passiveFace }
        }
        .frame(width: size.width)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .local)
                .onChanged { onDrag($0.translation) }
                .onEnded { _ in onDragEnd() }
        )
    }

    // MARK: - Passive

    private var passiveFace: some View {
        let d = tracker.today
        return VStack(alignment: .leading, spacing: size == .small ? 7 : 10) {
            header

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(d.total.hoursCompact)
                    .font(.system(size: size == .small ? 34 : 44, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("focused").font(size == .small ? .caption : .callout).foregroundStyle(.secondary)
            }

            SplitBar(human: d.humanTotal, agent: d.agentTotal, height: size == .small ? 10 : 12)

            if size != .small {
                HStack(spacing: 14) {
                    LegendDot(label: "You \(d.humanTotal.hoursCompact)", hatched: false)
                    LegendDot(label: "Agents \(d.agentTotal.hoursCompact)", hatched: true)
                }
            }

            if size == .medium, let top = tracker.sortedProjects.first {
                projectRow(top.name, top.time.total)
            }
            if size == .large {
                ForEach(tracker.sortedProjects.prefix(3), id: \.name) { p in
                    projectRow(p.name, p.time.total)
                }
            }

            footer(d)
        }
        .padding(16)
    }

    private func projectRow(_ name: String, _ time: TimeInterval) -> some View {
        HStack {
            Text(name).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(time.hoursCompact).font(.callout.weight(.bold)).monospacedDigit()
        }
    }

    @ViewBuilder private func footer(_ d: DayLog) -> some View {
        if !tracker.activeSessions.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "gearshape.2").font(.caption2)
                Text(tracker.totalAgentCount > 1 ? "\(tracker.totalAgentCount) agents working"
                                                 : "Agent on \(tracker.activeSessions.first?.projectName ?? "")")
                    .lineLimit(1).truncationMode(.middle)
            }
            .font(.caption2).foregroundStyle(.secondary)
        } else if d.total == 0 {
            Text("Start coding. This fills itself.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        if size == .large && tracker.editorKeystrokes > 0 {
            HStack(spacing: 5) {
                Image(systemName: "keyboard").font(.caption2)
                Text("\(tracker.editorKeystrokes) chars typed")
            }
            .font(.caption2).foregroundStyle(.secondary)
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
