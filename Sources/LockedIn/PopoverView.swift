import SwiftUI

/// The popover that drops from the menu bar. Two states: passive mirror, and locked-in.
struct PopoverView: View {
    @ObservedObject var tracker: Tracker
    var onToggleWidget: () -> Void = {}
    var onOpenDashboard: () -> Void = {}
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tracker.lockActive {
                LockedInView(tracker: tracker)
            } else {
                PassiveView(tracker: tracker, showShareSheet: $showShareSheet,
                            onToggleWidget: onToggleWidget, onOpenDashboard: onOpenDashboard)
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
    var onToggleWidget: () -> Void = {}
    var onOpenDashboard: () -> Void = {}
    @State private var loginEnabled = LoginItem.isEnabled

    var body: some View {
        let d = tracker.today
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tracker.hasSessionWindow ? "This session" : "Today").font(.headline)
                Spacer()
                LiveBadge(active: tracker.humanActiveNow || !tracker.activeAgents.isEmpty)
            }

            // The one dominant number — YOUR focused time, scoped to the current Claude
            // session window when connected (else today). Agents/details shown below.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(tracker.headlineFocused.hoursCompact)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .fixedSize()                       // never truncate the headline number
                    .contentTransition(.numericText())
                Text("focused").font(.callout).foregroundStyle(.secondary).fixedSize()
                Spacer(minLength: 6)
                if tracker.hasSessionWindow, let r = tracker.sessionResetsAt {
                    Text("resets \(r.untilCompact)")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).layoutPriority(-1)
                } else if d.agentTotal > 0 {
                    Text("+ \(d.agentTotal.hoursCompact) agents")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).layoutPriority(-1)
                }
            }

            // Below the session highlight, the day's breakdown (split + projects) — always today.
            if tracker.hasSessionWindow {
                Divider().padding(.vertical, 2)
                Text("Today").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
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

            if !tracker.activeSessions.isEmpty {
                AgentRunningRow(tracker: tracker)
            } else if d.total == 0 {
                Text("Open Cursor or Claude Code and this fills itself. Nothing to start.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            LockInButton(tracker: tracker)

            Divider().padding(.vertical, 4)

            // Primary action — big, obvious, easy to hit.
            Button(action: onOpenDashboard) {
                HStack(spacing: 9) {
                    Image(systemName: "square.grid.2x2")
                    Text("Open Dashboard").fontWeight(.medium)
                    Spacer()
                    if tracker.streak > 0 {
                        Label("\(tracker.streak)d", systemImage: "flame")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))

            // Controls row — left: actions. Right: widget controls. Generous tap targets.
            HStack(spacing: 4) {
                iconBtn("square.and.arrow.up", "Share card") { showShareSheet = true }
                Menu {
                    Toggle("Launch at login", isOn: $loginEnabled)
                    Divider()
                    Button("Quit LockedIn") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 32, height: 30).contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .foregroundStyle(.secondary)
                .onChange(of: loginEnabled) { _, want in loginEnabled = LoginItem.setEnabled(want) }

                Spacer()

                iconBtn("macwindow.on.rectangle", "Show/hide desktop widget", action: onToggleWidget)
                iconBtn(tracker.widgetPinned ? "pin.fill" : "pin",
                        tracker.widgetPinned ? "Pinned above apps" : "On desktop, behind apps",
                        tint: tracker.widgetPinned ? .accentColor : .primary) { tracker.toggleWidgetPin() }

                HStack(spacing: 0) {
                    ForEach(WidgetSize.allCases) { s in
                        Button { tracker.setWidgetSize(s) } label: {
                            Text(s.label).font(.caption.weight(.bold))
                                .frame(width: 34, height: 26)
                                .background(tracker.widgetSize == s ? Color.primary.opacity(0.14) : .clear)
                                .foregroundStyle(tracker.widgetSize == s ? Color.primary : .secondary)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).help("Widget size \(s.label)")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.secondary.opacity(0.3), lineWidth: 1))
                .padding(.leading, 2)
            }
        }
    }

    /// An icon button with a generous, fully-clickable hit area.
    private func iconBtn(_ symbol: String, _ help: String, tint: Color = .primary,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 32, height: 30)
                .foregroundStyle(tint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(help)
    }
}

private struct LockedInView: View {
    @ObservedObject var tracker: Tracker

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(tracker.lockProject ?? "Focus").font(.headline).lineLimit(1)
                Spacer()
                Text(tracker.lockPaused ? "PAUSED" : "LOCKED IN").font(.caption2.weight(.bold))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .overlay(Capsule().strokeBorder(.secondary, lineWidth: 1))
            }
            Text(tracker.lockRemaining.countdown)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .opacity(tracker.lockPaused ? 0.5 : 1)
            Text("agents still counting underneath")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button { tracker.togglePauseLock() } label: {
                    Label(tracker.lockPaused ? "Resume" : "Pause",
                          systemImage: tracker.lockPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                Button(role: .cancel) { tracker.endLock(completed: false) } label: {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
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
    @ObservedObject var tracker: Tracker
    @State private var expanded = false

    private var count: Int { tracker.totalAgentCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.2")
                    Text(count > 1 ? "\(count) agents running"
                                   : "Agent on \(tracker.activeSessions.first?.projectName ?? "project")")
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if count > 1 {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption2)
                    }
                }
                .font(.caption)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(count <= 1)

            if expanded {
                ForEach(Array(tracker.activeSessions.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 6) {
                        Circle().fill(.green).frame(width: 5, height: 5)
                        Text(s.projectName).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(s.sessionId.prefix(6)).foregroundStyle(.tertiary).monospaced()
                    }
                    .font(.caption2)
                    .padding(.leading, 4)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
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
