import SwiftUI

enum DashTab: String, CaseIterable, Identifiable {
    case dashboard, projects, calendar, agents, reports, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: "Dashboard"; case .projects: "Projects"; case .calendar: "Calendar"
        case .agents: "Agents & Tokens"; case .reports: "Reports"; case .settings: "Settings"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"; case .projects: "folder"; case .calendar: "calendar"
        case .agents: "cpu"; case .reports: "chart.bar.doc.horizontal"; case .settings: "gearshape"
        }
    }
}

/// One consistent card style across the whole dashboard.
extension View {
    func dashCard(_ pad: CGFloat = 14) -> some View {
        self.padding(pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

struct DashboardView: View {
    @ObservedObject var tracker: Tracker
    @State private var tab: DashTab = .dashboard
    // Read off the main thread, once — so tab switches never touch disk.
    @State private var monthValue: Double = 0

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView { content.padding(24) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 860, minHeight: 600)
        .task {
            let all = await Task.detached(priority: .userInitiated) { Store().allDays() }.value
            let month = String(DayLog.key().prefix(7))
            monthValue = all.filter { $0.date.hasPrefix(month) }.reduce(0) { $0 + $1.costToday }
            // Freshen live data when you open the dashboard.
            await UsageManager.shared.refresh()
            await StatusMonitor.shared.refresh()
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text("LockedIn").font(.headline)
            }
            .padding(.horizontal, 14).padding(.top, 16).padding(.bottom, 14)

            ForEach(DashTab.allCases) { t in
                Button { tab = t } label: {
                    HStack(spacing: 11) {
                        Image(systemName: t.icon).frame(width: 18)
                        Text(t.title)
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 7)
                        .fill(tab == t ? Color.primary.opacity(0.1) : .clear))
                    .fontWeight(tab == t ? .semibold : .regular)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()
            if tracker.streak > 0 {
                Label("\(tracker.streak)-day streak · \(tracker.today.humanTotal.hoursCompact) today",
                      systemImage: "flame")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(14)
            }
        }
        .frame(width: 210)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .dashboard: DashboardTab(tracker: tracker, monthValue: monthValue)
        case .projects: ProjectsTab(tracker: tracker)
        case .agents: AgentsTab(tracker: tracker)
        case .settings: SettingsTab(tracker: tracker)
        case .calendar: CalendarTab()
        case .reports: ReportsTab()
        }
    }
}

// MARK: - Dashboard tab

private struct DashboardTab: View {
    @ObservedObject var tracker: Tracker
    let monthValue: Double
    @State private var git: GitOutput?

    var body: some View {
        let d = tracker.today
        VStack(alignment: .leading, spacing: 22) {
            Text("Dashboard").font(.largeTitle.weight(.bold))

            // Hero — your focused time; agents are a separate stat.
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(d.humanTotal.hoursCompact).font(.system(size: 52, weight: .black, design: .rounded))
                Text("focused today")
                    .foregroundStyle(.secondary)
                if d.agentTotal > 0 {
                    Text("· + \(d.agentTotal.hoursCompact) agents")
                        .foregroundStyle(.secondary)
                }
            }
            SplitBar(human: d.humanTotal, agent: d.agentTotal, height: 14).frame(maxWidth: 620)
            HStack(spacing: 18) {
                LegendDot(label: "You \(d.humanTotal.hoursCompact)", hatched: false)
                LegendDot(label: "Agents \(d.agentTotal.hoursCompact)", hatched: true)
            }

            // Stat cards
            let cols = [GridItem(.adaptive(minimum: 180), spacing: 12)]
            LazyVGrid(columns: cols, spacing: 12) {
                StatCard(icon: "circle.hexagongrid", label: "Tokens today",
                         value: d.tokenTotal.total.tokensCompact,
                         detail: d.tokenTotal.total > 0 ? "≈ \(d.costToday.usd) API value" : "—")
                StatCard(icon: "cpu", label: "Prompts", value: "\(d.prompts)", detail: "to agents")
                StatCard(icon: "keyboard", label: "Typed",
                         value: tracker.editorKeystrokes.tokensCompact,
                         detail: tracker.editorGenerated > 0 ? "\(tracker.editorGenerated.tokensCompact) AI-generated" : "your keystrokes")
                StatCard(icon: "lock.fill", label: "Focus sessions",
                         value: "\(d.lockSessionsCompleted)", detail: "completed today")
                if let g = git, g.hasOutput {
                    StatCard(icon: "chevron.left.forwardslash.chevron.right", label: "Shipped today",
                             value: "\(g.commits) commit\(g.commits == 1 ? "" : "s")",
                             detail: "+\(g.added.tokensCompact) −\(g.deleted.tokensCompact) lines")
                }
            }
            .task(id: d.projects.keys.sorted().joined(separator: ",")) {
                let paths = tracker.projectPaths
                let names = Array(d.projects.keys)
                git = await Task.detached(priority: .utility) { () -> GitOutput in
                    var agg = GitOutput()
                    for n in names {
                        guard let p = paths[n], let o = GitStats.today(path: p) else { continue }
                        agg.add(o)
                    }
                    return agg
                }.value
            }

            // When you do your focused work today
            RhythmCard(hourly: d.hourly)

            // Claude usage limits + ROI
            UsageSection(monthValue: monthValue)

            // Service status
            StatusSection()

            // Projects table
            Text("Projects").font(.headline)
            ProjectsTable(tracker: tracker)
        }
    }
}

// MARK: - Projects tab

private struct ProjectsTab: View {
    @ObservedObject var tracker: Tracker
    @State private var all: [ProjectAggregate] = []
    @State private var expanded: Set<String> = []
    private var totalTokensAll: Int { all.reduce(0) { $0 + $1.tokenTotal } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Projects").font(.largeTitle.weight(.bold))
            Text("Every project you've worked on — click one to see its details.")
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                HStack {
                    Text("Project").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 20)
                    Text("You").frame(width: 70, alignment: .trailing)
                    Text("Agents").frame(width: 70, alignment: .trailing)
                    Text("Total").frame(width: 70, alignment: .trailing)
                    Text("Tokens").frame(width: 80, alignment: .trailing)
                    Text("Cost").frame(width: 70, alignment: .trailing)
                    Text("Last").frame(width: 90, alignment: .trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.vertical, 6)
                Divider()
                if all.isEmpty {
                    Text("No projects tracked yet.").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                }
                ForEach(all) { p in
                    let isOpen = expanded.contains(p.name)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isOpen { expanded.remove(p.name) } else { expanded.insert(p.name) }
                        }
                    } label: {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                                    .font(.caption2).foregroundStyle(.secondary).frame(width: 12)
                                Text(p.name).lineLimit(1).truncationMode(.middle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(p.human.hoursCompact).frame(width: 70, alignment: .trailing).monospacedDigit()
                            Text(p.agent.hoursCompact).frame(width: 70, alignment: .trailing).monospacedDigit()
                            Text(p.total.hoursCompact).frame(width: 70, alignment: .trailing).monospacedDigit().fontWeight(.semibold)
                            Text(p.tokenTotal > 0 ? p.tokenTotal.tokensCompact : "—").frame(width: 80, alignment: .trailing).monospacedDigit()
                            Text(p.cost > 0 ? p.cost.usd : "—").frame(width: 70, alignment: .trailing).foregroundStyle(.secondary)
                            Text(Self.lastActive(p.lastActive)).frame(width: 90, alignment: .trailing).font(.caption).foregroundStyle(.secondary)
                        }
                        .font(.callout).padding(.vertical, 8).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isOpen { ProjectDetail(p: p, totalTokens: totalTokensAll).padding(.leading, 20).padding(.bottom, 10) }
                    Divider().opacity(0.5)
                }
            }
        }
        .task { all = await Task.detached(priority: .userInitiated) { Store().projectTotals() }.value }
    }

    static func lastActive(_ key: String) -> String {
        if key == DayLog.key() { return "today" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: key) else { return key }
        let o = DateFormatter(); o.dateFormat = "d MMM"
        return o.string(from: d)
    }
}

/// The dropdown shown when a project row is expanded: split, model mix, busiest days.
private struct ProjectDetail: View {
    let p: ProjectAggregate
    let totalTokens: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                SplitBar(human: p.human, agent: p.agent, height: 10).frame(width: 200)
                LegendDot(label: "You \(p.human.hoursCompact)", hatched: false)
                LegendDot(label: "Agents \(p.agent.hoursCompact)", hatched: true)
            }

            // Usage share — this project's slice of your total token usage (a proxy for
            // "which project eats your limits"; Claude doesn't report limits per project).
            if totalTokens > 0 && p.tokenTotal > 0 {
                let share = Double(p.tokenTotal) / Double(totalTokens) * 100
                Text("Usage share").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08)).frame(width: 200, height: 8)
                        Capsule().fill(Theme.agent.opacity(0.75)).frame(width: max(4, 200 * share / 100), height: 8)
                    }
                    Text("\(Int(share.rounded()))% of your tokens").font(.caption)
                    Spacer()
                    Text("\(p.cost.usd) API value").font(.caption).foregroundStyle(.secondary)
                }
            }

            if !p.tokens.isEmpty {
                Text("Models used").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(p.tokens.sorted { $0.value.total > $1.value.total }, id: \.key) { model, c in
                    HStack {
                        Text(Pricing.shortName(model)).frame(width: 110, alignment: .leading)
                        Text("\(c.total.tokensCompact) tokens").monospacedDigit().foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Pricing.cost(model: model, c).usd) API value").foregroundStyle(.secondary)
                    }.font(.caption)
                }
            }

            Text("Most active days").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            let top = Array(p.mostActiveDays.prefix(7))
            let maxT = top.map(\.total).max() ?? 1
            ForEach(top) { d in
                HStack(spacing: 10) {
                    Text(ProjectsTab.lastActive(d.date)).font(.caption2).foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .leading)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08)).frame(width: 200, height: 8)
                        Capsule().fill(Theme.human).frame(width: max(4, 200 * CGFloat(d.total / maxT)), height: 8)
                    }
                    Text(d.total.hoursCompact).font(.caption2).monospacedDigit()
                        .frame(width: 56, alignment: .trailing).foregroundStyle(.secondary)
                }
            }
        }
        .dashCard(12)
    }
}

// MARK: - Agents & Tokens tab

private struct AgentsTab: View {
    @ObservedObject var tracker: Tracker
    var body: some View {
        let mix = tracker.today.tokensByModel.sorted { $0.value.total > $1.value.total }
        VStack(alignment: .leading, spacing: 18) {
            Text("Agents & Tokens").font(.largeTitle.weight(.bold))

            HStack(spacing: 24) {
                bigStat("\(tracker.today.tokenTotal.total.tokensCompact)", "tokens today")
                bigStat(tracker.today.costToday.usd, "estimated cost")
                bigStat("\(tracker.totalAgentCount)", "agents running now")
            }

            Text("Model mix").font(.headline)
            if mix.isEmpty {
                Text("No agent token usage yet today.").foregroundStyle(.secondary)
            } else {
                ForEach(mix, id: \.key) { model, c in
                    HStack {
                        Text(Pricing.shortName(model)).fontWeight(.medium).frame(width: 120, alignment: .leading)
                        ProgressView(value: Double(c.total),
                                     total: Double(max(tracker.today.tokenTotal.total, 1)))
                        Text(c.total.tokensCompact).monospacedDigit().frame(width: 70, alignment: .trailing)
                        Text(Pricing.cost(model: model, c).usd).foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
        }
    }
    private func bigStat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading) {
            Text(v).font(.system(size: 30, weight: .heavy, design: .rounded))
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Settings tab (widget customization)

private struct SettingsTab: View {
    @ObservedObject var tracker: Tracker
    @State private var loginEnabled = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Settings").font(.largeTitle.weight(.bold))

            section("Desktop widget") {
                // Live preview — updates as you change size and toggles.
                HStack {
                    Spacer()
                    DesktopWidgetView(tracker: tracker)
                        .frame(width: tracker.widgetSize.width)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(white: 0.13)))
                        .environment(\.colorScheme, .dark)
                        .allowsHitTesting(false)
                    Spacer()
                }
                .padding(.vertical, 4)

                Picker("Size", selection: Binding(
                    get: { tracker.widgetSize }, set: { tracker.setWidgetSize($0) })) {
                    ForEach(WidgetSize.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)

                Divider().padding(.vertical, 4)
                Text("Show on the widget").font(.caption).foregroundStyle(.secondary)
                ForEach(WidgetComponent.allCases) { comp in
                    Toggle(isOn: binding(for: comp)) {
                        Label(comp.label, systemImage: comp.icon)
                    }
                }
                Divider().padding(.vertical, 4)
                Toggle("Combine projects into one total", isOn: Binding(
                    get: { tracker.widgetConfig.combineProjects },
                    set: { var c = tracker.widgetConfig; c.combineProjects = $0; tracker.updateWidgetConfig(c) }))
                Toggle("Pin widget above all windows", isOn: Binding(
                    get: { tracker.widgetPinned },
                    set: { _ in tracker.toggleWidgetPin() }))
            }

            section("Claude usage limits") {
                ConnectUsage()
            }

            section("Claude status alerts") {
                Toggle("Notify me when a service goes down", isOn: Binding(
                    get: { StatusMonitor.shared.notifyOnOutage },
                    set: { StatusMonitor.shared.notifyOnOutage = $0 }))
                Button("Send test notification") { StatusMonitor.shared.sendTest() }
                Text("Tick the services you use — only these trigger alerts.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(StatusMonitor.shared.services) { s in
                    Toggle(isOn: Binding(
                        get: { StatusMonitor.shared.tracked.contains(s.name) },
                        set: { on in
                            if on { StatusMonitor.shared.tracked.insert(s.name) }
                            else { StatusMonitor.shared.tracked.remove(s.name) }
                        })) {
                        HStack(spacing: 8) {
                            Circle().fill(s.color).frame(width: 7, height: 7)
                            Text(s.name)
                        }
                    }
                }
            }

            section("General") {
                Toggle("Launch at login", isOn: $loginEnabled)
                    .onChange(of: loginEnabled) { _, want in loginEnabled = LoginItem.setEnabled(want) }
                Text("Notification muting during Lock In uses a macOS Shortcut named \"LockedIn Focus On/Off\".")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding(for comp: WidgetComponent) -> Binding<Bool> {
        Binding(
            get: { tracker.widgetConfig.isOn(comp) },
            set: { on in
                var cfg = tracker.widgetConfig
                if on { if !cfg.components.contains(comp) { cfg.components.append(comp) } }
                else { cfg.components.removeAll { $0 == comp } }
                cfg.components = WidgetComponent.allCases.filter { cfg.components.contains($0) }
                tracker.updateWidgetConfig(cfg)
            })
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .dashCard(16)
    }
}

// MARK: - Shared pieces

private struct ConnectUsage: View {
    @ObservedObject private var usage = UsageManager.shared
    @State private var key = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if usage.connected {
                HStack {
                    Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    if let t = usage.lastChecked {
                        Text("updated \(t.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh") { Task { await usage.refresh() } }
                    Button("Disconnect") { usage.disconnect() }
                }
                if let e = usage.error {
                    Label(e, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text("Paste your whole claude.ai Cookie (or just the sessionKey). Only the sessionKey is kept, stored locally on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("paste cookie or sessionKey…", text: $key)
                        .textFieldStyle(.roundedBorder)
                    Button("Connect") { usage.connect(key); key = "" }.disabled(key.isEmpty)
                }
            }
            Picker("Plan (for ROI)", selection: Binding(get: { usage.plan }, set: { usage.plan = $0 })) {
                ForEach(Plan.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented)
            Text("Get the cookie: on claude.ai (logged in), open dev tools → Application/Storage → Cookies → claude.ai, copy the whole thing (or just the sessionKey), and paste it above.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

private struct UsageSection: View {
    @ObservedObject private var usage = UsageManager.shared
    let monthValue: Double   // pre-loaded off the main thread

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude usage").font(.headline)
            if !usage.connected {
                Text("Connect your Claude account in Settings to see your session and weekly limits.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                bar("Session (5 hour)", usage.session)
                bar("Weekly (7 day)", usage.weekly)
                bar("Weekly Sonnet (7 day)", usage.weeklySonnet)
                if let e = usage.error {
                    Label(e, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            }

            Divider().padding(.vertical, 2)
            // ROI: API-equivalent value vs flat subscription price.
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("This month: **\(monthValue.usd)** of API value on your \(usage.plan.label) plan")
                if usage.plan.monthlyPrice > 0 {
                    Text("(\(String(format: "%.1f×", monthValue / usage.plan.monthlyPrice)))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
        .dashCard()
    }

    @ViewBuilder private func bar(_ title: String, _ w: UsageWindow?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.callout.weight(.medium))
                Spacer()
                if let r = w?.resetsAt {
                    Text("resets \(r.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: min((w?.percent ?? 0) / 100, 1))
            Text("\(Int(w?.percent ?? 0))% used").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct StatusSection: View {
    @ObservedObject private var status = StatusMonitor.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Claude status").font(.headline)
                Circle().fill(status.allOperational ? .green : .orange).frame(width: 8, height: 8)
                Text(status.summary).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let t = status.lastChecked {
                    Text("checked \(t.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            ForEach(status.services) { s in
                HStack(spacing: 8) {
                    Circle().fill(s.color).frame(width: 7, height: 7)
                    Text(s.name).font(.callout)
                    Spacer()
                    Text(s.isOK ? "Operational" : s.label)
                        .font(.caption).foregroundStyle(s.isOK ? .secondary : .primary)
                }
            }
            ForEach(status.incidents, id: \.self) { inc in
                Label(inc, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .dashCard()
    }
}

private struct StatCard: View {
    let icon: String, label: String, value: String, detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded))
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .dashCard()
    }
}

/// 24-hour strip of YOUR focused time — shows the shape of your day and your peak hour.
private struct RhythmCard: View {
    let hourly: [Int: TimeInterval]

    private var peak: Int? {
        hourly.filter { $0.value > 0 }.max { $0.value < $1.value }?.key
    }
    private var maxVal: TimeInterval { max(hourly.values.max() ?? 0, 1) }

    private func hourLabel(_ h: Int) -> String {
        let am = h < 12
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12)\(am ? "am" : "pm")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Today's rhythm", systemImage: "waveform.path.ecg")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let p = peak {
                    Text("Peak \(hourLabel(p))–\(hourLabel((p + 1) % 24))")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            if hourly.values.reduce(0, +) == 0 {
                Text("Fills in as you work through the day.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
            } else {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<24, id: \.self) { h in
                        let v = hourly[h] ?? 0
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(h == peak ? Theme.accent : Theme.human.opacity(v > 0 ? 0.55 : 0.08))
                                .frame(height: max(3, CGFloat(v / maxVal) * 56))
                        }
                        .frame(maxWidth: .infinity)
                        .help(v > 0 ? "\(hourLabel(h)): \(v.hoursCompact)" : hourLabel(h))
                    }
                }
                .frame(height: 56)
                // Sparse axis: midnight, 6a, noon, 6p, 11p
                HStack(spacing: 0) {
                    ForEach([0, 6, 12, 18, 23], id: \.self) { h in
                        Text(hourLabel(h)).font(.system(size: 9)).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: h == 0 ? .leading : (h == 23 ? .trailing : .center))
                    }
                }
            }
        }
        .dashCard()
    }
}

private struct ProjectsTable: View {
    @ObservedObject var tracker: Tracker
    var body: some View {
        let projects = tracker.sortedProjects
        VStack(spacing: 0) {
            HStack {
                Text("Project").frame(maxWidth: .infinity, alignment: .leading)
                Text("You").frame(width: 70, alignment: .trailing)
                Text("Agents").frame(width: 70, alignment: .trailing)
                Text("Tokens").frame(width: 80, alignment: .trailing)
                Text("Cost").frame(width: 70, alignment: .trailing)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.vertical, 6)
            Divider()
            if projects.isEmpty {
                Text("Nothing tracked yet today.").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
            }
            ForEach(projects, id: \.name) { p in
                let tk = tracker.today.tokens[p.name] ?? [:]
                let counts = tk.values.reduce(into: TokenCounts()) { $0.add($1) }
                let cost = tk.reduce(0.0) { $0 + Pricing.cost(model: $1.key, $1.value) }
                HStack {
                    Text(p.name).lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(p.time.human.hoursCompact).frame(width: 70, alignment: .trailing).monospacedDigit()
                    Text(p.time.agent.hoursCompact).frame(width: 70, alignment: .trailing).monospacedDigit()
                    Text(counts.total > 0 ? counts.total.tokensCompact : "—").frame(width: 80, alignment: .trailing).monospacedDigit()
                    Text(cost > 0 ? cost.usd : "—").frame(width: 70, alignment: .trailing).foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 7)
                Divider().opacity(0.5)
            }
        }
    }
}

// MARK: - Calendar tab (contribution-style heatmap)

private struct CalendarTab: View {
    @State private var byDate: [String: DayLog] = [:]
    private let weeks = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Calendar").font(.largeTitle.weight(.bold))
            Text("Your focus over time — each square is a day, brighter means more work. Hover for details.")
                .foregroundStyle(.secondary)

            let maxT = max(byDate.values.map(\.total).max() ?? 1, 1)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(0..<weeks, id: \.self) { w in
                        VStack(spacing: 3) { ForEach(0..<7, id: \.self) { d in cell(week: w, day: d, maxT: maxT) } }
                    }
                }
                // Legend
                HStack(spacing: 5) {
                    Text("Less").font(.caption2).foregroundStyle(.secondary)
                    ForEach([0.06, 0.25, 0.45, 0.7, 1.0], id: \.self) { o in
                        RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(o)).frame(width: 13, height: 13)
                    }
                    Text("More").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .dashCard()
        }
        .task {
            let all = await Task.detached(priority: .userInitiated) { Store().allDays() }.value
            byDate = Dictionary(uniqueKeysWithValues: all.map { ($0.date, $0) })
        }
    }

    private func cell(week: Int, day: Int, maxT: TimeInterval) -> some View {
        let cal = Calendar.current
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let start = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: startOfWeek) ?? Date()
        let date = cal.date(byAdding: .day, value: week * 7 + day, to: start) ?? Date()
        let key = DayLog.key(for: date)
        let log = byDate[key]
        let total = log?.humanTotal ?? 0   // brightness = your focused time
        let future = date > Date()
        return RoundedRectangle(cornerRadius: 3)
            .fill(future ? Color.primary.opacity(0.02) : Color.primary.opacity(intensity(total)))
            .frame(width: 15, height: 15)
            .help(future ? "" : tooltip(key, log))
    }

    private func intensity(_ t: TimeInterval) -> Double {
        switch t {
        case 0: 0.06
        case ..<1800: 0.25       // < 30m
        case ..<3600: 0.45       // < 1h
        case ..<7200: 0.7        // < 2h
        default: 1.0
        }
    }

    private func tooltip(_ key: String, _ day: DayLog?) -> String {
        guard let day, day.total > 0 else { return "\(key) · nothing tracked" }
        var s = "\(key) · \(day.humanTotal.hoursCompact) focused"
        if day.agentTotal > 0 { s += " · + \(day.agentTotal.hoursCompact) agents" }
        if day.tokenTotal.total > 0 { s += "\n\(day.tokenTotal.total.tokensCompact) tokens · \(day.costToday.usd) API value" }
        return s
    }
}

// MARK: - Reports tab (all-time totals + CSV export)

private struct ReportsTab: View {
    @State private var days = 0
    @State private var totalTime: TimeInterval = 0
    @State private var agentTime: TimeInterval = 0
    @State private var totalTokens = 0
    @State private var totalCost: Double = 0
    @State private var projectCount = 0
    @State private var exported: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Reports").font(.largeTitle.weight(.bold))
            Text("All-time totals and a CSV export for invoicing or analysis.")
                .foregroundStyle(.secondary)

            let cols = [GridItem(.adaptive(minimum: 180), spacing: 12)]
            LazyVGrid(columns: cols, spacing: 12) {
                StatCard(icon: "clock", label: "Your focused time", value: totalTime.hoursCompact, detail: "\(days) day\(days == 1 ? "" : "s") tracked")
                StatCard(icon: "gearshape.2", label: "Agent time", value: agentTime.hoursCompact, detail: "ran for you")
                StatCard(icon: "folder", label: "Projects", value: "\(projectCount)", detail: "all time")
                StatCard(icon: "circle.hexagongrid", label: "Tokens", value: totalTokens.tokensCompact, detail: totalCost.usd + " API value")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Export").font(.headline)
                Text("One row per day per project: date, project, your minutes, agent minutes, tokens, API cost.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button { export() } label: { Label("Export CSV", systemImage: "square.and.arrow.down") }
                    if let e = exported {
                        Label("Saved \(e)", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                    }
                }
            }
            .dashCard(16)
        }
        .task {
            let all = await Task.detached(priority: .userInitiated) { Store().allDays() }.value
            days = all.filter { $0.total > 0 }.count
            totalTime = all.reduce(0) { $0 + $1.humanTotal }
            agentTime = all.reduce(0) { $0 + $1.agentTotal }
            totalTokens = all.reduce(0) { $0 + $1.tokenTotal.total }
            totalCost = all.reduce(0) { $0 + $1.costToday }
            projectCount = Set(all.flatMap { Array($0.projects.keys) + Array($0.tokens.keys) }).count
        }
    }

    private func export() {
        Task {
            let csv = await Task.detached(priority: .userInitiated) { ReportsTab.buildCSV(Store().allDays()) }.value
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let url = downloads.appendingPathComponent("LockedIn-export-\(DayLog.key()).csv")
            try? csv.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            exported = url.lastPathComponent
        }
    }

    /// One row per (day, project). Numbers only.
    nonisolated static func buildCSV(_ days: [DayLog]) -> String {
        var rows = ["date,project,you_minutes,agent_minutes,tokens,api_cost_usd"]
        for day in days.sorted(by: { $0.date < $1.date }) {
            let names = Set(day.projects.keys).union(day.tokens.keys).sorted()
            for name in names {
                let pt = day.projects[name]
                let you = Int((pt?.human ?? 0) / 60)
                let agent = Int((pt?.agent ?? 0) / 60)
                let tk = day.tokens[name] ?? [:]
                let tokens = tk.values.reduce(0) { $0 + $1.total }
                let cost = tk.reduce(0.0) { $0 + Pricing.cost(model: $1.key, $1.value) }
                let safe = name.replacingOccurrences(of: "\"", with: "\"\"")
                rows.append("\(day.date),\"\(safe)\",\(you),\(agent),\(tokens),\(String(format: "%.2f", cost))")
            }
        }
        return rows.joined(separator: "\n")
    }
}

private struct ComingSoon: View {
    let title: String, note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.largeTitle.weight(.bold))
            HStack(spacing: 8) {
                Image(systemName: "hammer").foregroundStyle(.secondary)
                Text(note).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
        }
    }
}
