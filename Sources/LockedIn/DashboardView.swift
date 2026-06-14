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

struct DashboardView: View {
    @ObservedObject var tracker: Tracker
    @State private var tab: DashTab = .dashboard
    // History is read off the main thread, once — so tab switches never touch disk.
    @State private var week: [DayLog] = []
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
            let w = await Task.detached(priority: .userInitiated) { Store().recentDays(7) }.value
            let all = await Task.detached(priority: .userInitiated) { Store().allDays() }.value
            let month = String(DayLog.key().prefix(7))
            week = w
            monthValue = all.filter { $0.date.hasPrefix(month) }.reduce(0) { $0 + $1.costToday }
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
                Label("\(tracker.streak)-day streak · \(tracker.today.total.hoursCompact) today",
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
        case .dashboard: DashboardTab(tracker: tracker, week: week, monthValue: monthValue)
        case .projects: ProjectsTab(tracker: tracker)
        case .agents: AgentsTab(tracker: tracker)
        case .settings: SettingsTab(tracker: tracker)
        case .calendar: ComingSoon(title: "Calendar", note: "A day-by-day timeline of projects and focus sessions.")
        case .reports: ComingSoon(title: "Reports", note: "CSV export and billing-style summaries.")
        }
    }
}

// MARK: - Dashboard tab

private struct DashboardTab: View {
    @ObservedObject var tracker: Tracker
    let week: [DayLog]            // pre-loaded off the main thread
    let monthValue: Double

    var body: some View {
        let d = tracker.today
        VStack(alignment: .leading, spacing: 22) {
            Text("Dashboard").font(.largeTitle.weight(.bold))

            // Hero
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(d.total.hoursCompact).font(.system(size: 52, weight: .black, design: .rounded))
                Text("focused today · \(tracker.sortedProjects.count) project\(tracker.sortedProjects.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
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
            }

            // Claude usage limits + ROI
            UsageSection(monthValue: monthValue)

            // Service status
            StatusSection()

            // Week chart
            Text("This week").font(.headline)
            WeekChart(days: week)

            // Projects table
            Text("Projects").font(.headline)
            ProjectsTable(tracker: tracker)
        }
    }
}

// MARK: - Projects tab

private struct ProjectsTab: View {
    @ObservedObject var tracker: Tracker
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Projects").font(.largeTitle.weight(.bold))
            Text("Today's work per project — time split, tokens, and estimated cost.")
                .foregroundStyle(.secondary)
            ProjectsTable(tracker: tracker)
        }
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
                Text("Pick what the widget shows. Reorder coming soon.")
                    .font(.caption).foregroundStyle(.secondary)
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
        .frame(maxWidth: 520, alignment: .leading)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
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
                    Button("Disconnect") { usage.disconnect() }
                }
                if let e = usage.error {
                    Label(e, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text("Paste your whole claude.ai Cookie (or just the sessionKey). Only the sessionKey is kept, in your Keychain.")
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
        .padding(14)
        .frame(maxWidth: 620, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
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
        .padding(14)
        .frame(maxWidth: 620, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))
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

private struct WeekChart: View {
    let days: [DayLog]
    var body: some View {
        let maxTotal = max(days.map(\.total).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days, id: \.date) { day in
                VStack(spacing: 5) {
                    Spacer(minLength: 0)
                    VStack(spacing: 0) {
                        Rectangle().fill(Theme.agent.opacity(0.55))
                            .frame(height: barHeight(day.agentTotal, maxTotal))
                        Rectangle().fill(Theme.human)
                            .frame(height: barHeight(day.humanTotal, maxTotal))
                    }
                    .frame(width: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(weekday(day.date)).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 150, alignment: .bottom)
        .frame(maxWidth: 620, alignment: .leading)
    }
    private func barHeight(_ v: TimeInterval, _ maxTotal: TimeInterval) -> CGFloat {
        CGFloat(v / maxTotal) * 120
    }
    private func weekday(_ key: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: key) else { return "" }
        let w = DateFormatter(); w.dateFormat = "EEE"
        return w.string(from: d)
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
