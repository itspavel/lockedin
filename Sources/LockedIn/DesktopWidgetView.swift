import SwiftUI

/// The always-on-desktop widget content. Glanceable: one number, the split bar,
/// the top project, and live agent state. Tuned to read from across the room.
struct DesktopWidgetView: View {
    @ObservedObject var tracker: Tracker

    var body: some View {
        if tracker.lockActive {
            lockedFace
        } else {
            passiveFace
        }
    }

    private var passiveFace: some View {
        let d = tracker.today
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                if tracker.editorConnected || !tracker.activeSessions.isEmpty || tracker.humanActiveNow {
                    Circle().fill(.green).frame(width: 7, height: 7)
                }
                pinButton
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(d.total.hoursCompact)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("focused").font(.callout).foregroundStyle(.secondary)
            }

            SplitBar(human: d.humanTotal, agent: d.agentTotal, height: 12)
            HStack(spacing: 14) {
                LegendDot(label: "You \(d.humanTotal.hoursCompact)", hatched: false)
                LegendDot(label: "Agents \(d.agentTotal.hoursCompact)", hatched: true)
            }

            if let top = tracker.sortedProjects.first {
                HStack {
                    Text(top.name).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(top.time.total.hoursCompact).font(.callout.weight(.bold)).monospacedDigit()
                }
                .padding(.top, 2)
            }

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
        }
        .padding(16)
        .frame(width: 240)
    }

    private var lockedFace: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill").font(.caption)
                Text(tracker.lockProject ?? "Focus").font(.caption.weight(.bold)).lineLimit(1)
                Spacer()
                pinButton
            }
            Text(tracker.lockRemaining.countdown)
                .font(.system(size: 44, weight: .heavy, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText())
                .opacity(tracker.lockPaused ? 0.5 : 1)
            Text(tracker.lockPaused ? "paused" : "locked in")
                .font(.caption2).foregroundStyle(.secondary)

            // Pause/Stop right on the widget — no need to open the menu bar.
            HStack(spacing: 8) {
                widgetControl(tracker.lockPaused ? "play.fill" : "pause.fill") { tracker.togglePauseLock() }
                widgetControl("stop.fill") { tracker.endLock(completed: false) }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 240)
    }

    private var pinButton: some View {
        Button { tracker.toggleWidgetPin() } label: {
            Image(systemName: tracker.widgetPinned ? "pin.fill" : "pin")
                .font(.caption2)
                .foregroundStyle(tracker.widgetPinned ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(tracker.widgetPinned ? "Pinned above apps — click to send to desktop"
                                   : "On desktop — click to pin above apps")
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
