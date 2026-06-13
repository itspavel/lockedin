import SwiftUI

/// The popover that drops from the menu bar. Two states: passive mirror, and locked-in.
struct PopoverView: View {
    @ObservedObject var tracker: Tracker
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lock = tracker.lockSession {
                LockedInView(tracker: tracker, lock: lock)
            } else {
                PassiveView(tracker: tracker, showShareSheet: $showShareSheet)
            }
        }
        .padding(18)
        .frame(width: 320)
        .sheet(isPresented: $showShareSheet) {
            ShareCardSheet(tracker: tracker)
        }
    }
}

private struct PassiveView: View {
    @ObservedObject var tracker: Tracker
    @Binding var showShareSheet: Bool

    var body: some View {
        let d = tracker.today
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today").font(.headline)
                Spacer()
                LiveBadge(active: tracker.humanActiveNow || !tracker.activeAgents.isEmpty)
            }

            // The one dominant number.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(d.total.hoursCompact)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("focused").font(.callout).foregroundStyle(.secondary)
            }

            SplitBar(human: d.humanTotal, agent: d.agentTotal)
            HStack(spacing: 16) {
                LegendDot(label: "You \(d.humanTotal.hoursCompact)", hatched: false)
                LegendDot(label: "Agents \(d.agentTotal.hoursCompact)", hatched: true)
            }

            if !tracker.sortedProjects.isEmpty {
                Divider().padding(.vertical, 2)
                ForEach(tracker.sortedProjects.prefix(4), id: \.name) { p in
                    HStack {
                        Text(p.name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(p.time.total.hoursCompact).fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.callout)
                }
            }

            if let agent = tracker.activeAgents.first {
                AgentRunningRow(name: agent.projectName, count: tracker.activeAgents.count)
            } else if d.total == 0 {
                Text("Open Cursor or Claude Code and this fills itself. Nothing to start.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            LockInButton(tracker: tracker)

            HStack(spacing: 14) {
                Button { showShareSheet = true } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                if tracker.editorConnected {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .foregroundStyle(.green).help("Editor sensor connected")
                }
                Spacer()
                if tracker.streak > 0 {
                    Label("\(tracker.streak)-day streak", systemImage: "flame")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }
}

private struct LockedInView: View {
    @ObservedObject var tracker: Tracker
    let lock: LockSession

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(lock.project ?? "Focus").font(.headline).lineLimit(1)
                Spacer()
                Text("LOCKED IN").font(.caption2.weight(.bold))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .overlay(Capsule().strokeBorder(.secondary, lineWidth: 1))
            }
            Text(lock.remaining.countdown)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("agents still counting underneath")
                .font(.caption).foregroundStyle(.secondary)

            Button(role: .cancel) { tracker.endLock(completed: false) } label: {
                Text("End session early").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
    }
}

private struct LiveBadge: View {
    let active: Bool
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(active ? Color.green : Color.secondary).frame(width: 7, height: 7)
            Text(active ? "LIVE" : "IDLE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
    }
}

private struct AgentRunningRow: View {
    let name: String
    let count: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "gearshape.2")
            Text(count > 1 ? "\(count) agents running" : "Agent running on \(name)")
                .lineLimit(1).truncationMode(.middle)
        }
        .font(.caption)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3])))
    }
}

private struct LockInButton: View {
    @ObservedObject var tracker: Tracker
    @State private var minutes = 45
    private let options = [25, 45, 60, 90]

    var body: some View {
        VStack(spacing: 8) {
            // Duration pills — tap to choose, selected one is filled.
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { m in
                    Text("\(m)m")
                        .font(.caption.weight(.semibold)).monospacedDigit()
                        .padding(.vertical, 4).frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(m == minutes ? Color.primary.opacity(0.12) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(Color.primary.opacity(m == minutes ? 0.4 : 0.15), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { minutes = m }
                }
            }

            Button { tracker.startLock(minutes: minutes, project: tracker.currentProject) } label: {
                Label("Lock In · \(minutes) min", systemImage: "lock.fill")
                    .font(.callout.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary))
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
        }
    }
}
