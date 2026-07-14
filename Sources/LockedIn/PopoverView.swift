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
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
        .tint(Theme.accent)
        .sheet(isPresented: $showShareSheet) {
            ShareCardSheet(tracker: tracker)
        }
    }
}

private struct PassiveView: View {
    @ObservedObject var tracker: Tracker
    @ObservedObject private var usage = UsageManager.shared
    @Binding var showShareSheet: Bool
    var onToggleWidget: () -> Void = {}
    var onOpenDashboard: () -> Void = {}
    @State private var loginEnabled = LoginItem.isEnabled

    var body: some View {
        let d = tracker.today
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                BrandMark(size: 15)
                Text("Today").font(.headline)
                Spacer()
                LiveBadge(active: tracker.humanActiveNow || !tracker.activeAgents.isEmpty)
            }

            // The one dominant number — YOUR focused time today (midnight–midnight).
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(d.humanTotal.hoursCompact)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .fixedSize()                       // never truncate the headline number
                    .contentTransition(.numericText())
                Text("focused").font(.callout).foregroundStyle(.secondary).fixedSize()
                if d.agentTotal > 0 {
                    Spacer(minLength: 6)
                    Text("+ \(d.agentTotal.hoursCompact) agents")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).layoutPriority(-1)
                }
            }

            SplitBar(human: d.humanTotal, agent: d.agentTotal)
            HStack(spacing: 16) {
                LegendDot(label: "You \(d.humanTotal.hoursCompact)", hatched: false)
                LegendDot(label: "Agents \(d.agentTotal.hoursCompact)", hatched: true)
            }

            if usage.connected {
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 5) {
                    Text("CLAUDE LIMITS").font(.system(size: 9, weight: .bold)).tracking(1.2)
                        .foregroundStyle(.tertiary)
                    ForEach(usage.limits) { usageRow($0) }
                    if let r = usage.session?.resetsAt {
                        Text("Session resets \(r.untilCompact) · \(r.clockTime)")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    ClaudeStatusLine().padding(.top, 1)
                }
            }

            // Project rows hidden for now (per request).

            if !tracker.activeSessions.isEmpty {
                AgentRunningRow(tracker: tracker)
            } else if d.total == 0 {
                Text("Open Cursor or Claude Code and this fills itself. Nothing to start.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            Divider().padding(.vertical, 4)

            // Primary action — the signature yellow CTA.
            Button(action: onOpenDashboard) {
                HStack(spacing: 9) {
                    Image(systemName: "square.grid.2x2")
                    Text("Open Dashboard").fontWeight(.bold)
                    Spacer()
                    if tracker.streak > 0 {
                        Label("\(tracker.streak)d", systemImage: "flame").font(.caption)
                    }
                    Image(systemName: "chevron.right").font(.caption2)
                }
                .foregroundStyle(Theme.accentText)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accent))

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
                        tint: tracker.widgetPinned ? Theme.accent : .primary) { tracker.toggleWidgetPin() }
            }
        }
    }

    /// A compact Claude-usage limit row: label, a capsule that warns as it fills, percent.
    private func usageRow(_ limit: UsageLimit) -> some View {
        let pct = limit.percent
        let fill: Color = pct >= 90 ? .red : pct >= 70 ? .orange : Theme.accent
        return HStack(spacing: 8) {
            Text(limit.label).font(.caption2.weight(limit.active ? .bold : .medium))
                .foregroundStyle(limit.active ? .primary : .secondary)
                .frame(width: 56, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule().fill(fill.opacity(pct >= 70 ? 0.9 : 0.8))
                        .frame(width: max(5, geo.size.width * min(pct / 100, 1)))
                }
            }
            .frame(height: 5)
            Text("\(Int(pct))%").font(.caption2.weight(.semibold)).monospacedDigit()
                .foregroundStyle(pct >= 90 ? .red : .secondary)
                .frame(width: 34, alignment: .trailing)
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

