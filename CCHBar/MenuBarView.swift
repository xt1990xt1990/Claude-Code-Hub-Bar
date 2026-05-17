import SwiftUI

private enum CCHPanelLayout {
    static let width: CGFloat = 760
    static let contentWidth: CGFloat = 732
    static let scrollHeight: CGFloat = 525
}

struct CCHLogoMark: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.black)
            CCHTriangleMark()
                .fill(Color.white)
                .frame(width: size * 0.52, height: size * 0.50)
                .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.28), radius: 4, y: 1)
    }
}

private struct CCHTriangleMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct MenuBarView: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(state: state)
            Divider().opacity(0.35)
            Picker("", selection: $state.selectedTab) {
                ForEach(CCHPanelTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.25)

            ScrollView {
                Group {
                    switch state.selectedTab {
                    case .dashboard:
                        DashboardTabView(state: state)
                    case .leaderboard:
                        LeaderboardTabView(state: state)
                    case .logs:
                        LogsTabView(state: state)
                    case .providers:
                        ProvidersTabView(state: state)
                    }
                }
                .frame(width: CCHPanelLayout.contentWidth, alignment: .topLeading)
                .padding(14)
                .id(state.selectedTab)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            }
            .frame(width: CCHPanelLayout.width, height: CCHPanelLayout.scrollHeight)
            .onChange(of: state.selectedTab) { _, _ in
                Task { await state.refreshFocusedView() }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: state.selectedTab)

            Divider().opacity(0.25)
            FooterView(state: state)
        }
        .frame(width: CCHPanelLayout.width)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.orange.opacity(0.06),
                    Color.purple.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .animation(.easeInOut(duration: 0.18), value: state.isLoading)
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: state.recentLogs.map(\.id))
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: state.logs.map(\.id))
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: state.providers.map(\.id))
        .onAppear {
            state.setPanelVisible(true)
        }
        .onDisappear {
            state.setPanelVisible(false)
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var state: MonitorState
    @State private var hoveringProjectLink = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if let url = URL(string: "https://github.com/ding113/claude-code-hub") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                CCHLogoMark(size: 28)
            }
            .buttonStyle(.plain)
            .help("打开 Claude Code Hub 项目")
            .opacity(hoveringProjectLink ? 0.86 : 1)
            .onHover { hovering in
                hoveringProjectLink = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Code Hub")
                    .font(.system(size: 15, weight: .semibold))
                Text("总览 · 日志 · 渠道")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if state.isLoading {
                ProgressView()
                    .scaleEffect(0.72)
            }
            Button {
                Task { await state.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("刷新")
            Button {
                state.openCCH()
            } label: {
                Image(systemName: "safari")
            }
            .buttonStyle(.borderless)
            .help("打开 CCH")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct FooterView: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(spacing: 7) {
            if let error = state.errorMessage, !error.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .lineLimit(2)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if let message = state.actionMessage, !message.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(message)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.green)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            HStack {
                if let last = state.lastRefresh {
                    Text("更新于 \(last.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                FooterActionButton(title: "设置", icon: "gearshape") {
                    SettingsWindowManager.shared.open(state: state)
                }
                FooterActionButton(title: "退出", icon: "power", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.18), value: state.errorMessage)
        .animation(.easeInOut(duration: 0.18), value: state.actionMessage)
    }
}

private struct FooterActionButton: View {
    enum Role {
        case normal
        case destructive
    }

    let title: String
    let icon: String
    var role: Role = .normal
    let action: () -> Void
    @State private var hovering = false

    var color: Color {
        role == .destructive ? .red : .blue
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(hovering ? color.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.52))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(hovering ? 0.35 : 0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? color : (hovering ? color : .secondary))
        .onHover { isHovering in
            hovering = isHovering
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private struct DashboardTabView: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RunningRequestsPanel(state: state)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                MetricCard(title: "成本", value: formatMoney(state.overview.todayCost), detail: "今日", color: .green, icon: "dollarsign.circle")
                MetricCard(title: "请求", value: compactNumber(state.overview.todayRequests), detail: "\(state.overview.recentMinuteRequests)/分钟", color: .cyan, icon: "bolt.horizontal.circle")
                MetricCard(title: "会话", value: "\(state.overview.concurrentSessions)", detail: "\(state.menuBarRunningLogs.count) 运行中", color: .purple, icon: "play.circle")
                MetricCard(title: "缓存", value: formatPercent(cacheHitRate(cacheReadTokens: state.logSummary.cacheReadTokens, inputTokens: state.logSummary.inputTokens)), detail: "命中率", color: .mint, icon: "memorychip")
            }

            HStack(alignment: .top, spacing: 12) {
                RecentRequestsPanel(state: state)
                ProviderHealthPanel(state: state)
            }
        }
    }
}

private struct RunningRequestsPanel: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(
                title: state.menuBarRunningLogs.isEmpty ? "暂无运行请求" : "运行中请求",
                actionTitle: "打开",
                action: { state.openCCH("/zh-CN/dashboard/logs") }
            )

            if state.menuBarRunningLogs.isEmpty {
                HStack(spacing: 10) {
                    StatusDot(color: .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("空闲")
                            .font(.system(size: 13, weight: .semibold))
                        Text("今日 \(compactNumber(state.overview.todayRequests)) 次请求 · \(formatMoney(state.overview.todayCost))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(11)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(state.menuBarRunningLogs.prefix(4)) { log in
                    RunningRequestRow(state: state, log: log)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(11)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.22), lineWidth: 1))
    }
}

private struct RunningRequestRow: View {
    @ObservedObject var state: MonitorState
    let log: CCHLogEntry

    var model: String {
        log.model.isEmpty ? log.originalModel : log.model
    }

    func runningDurationText(_ log: CCHLogEntry) -> String {
        guard let date = parseCCHDate(log.createdAt) else { return "--" }
        return formatDuration(Date().timeIntervalSince(date))
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.22), lineWidth: 2)
                    .frame(width: 18, height: 18)
                CCHTriangleMark()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .offset(x: 0.5)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(log.providerName.isEmpty ? "渠道" : log.providerName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    MultiplierBadge(value: state.providerMultiplier(for: log.providerName))
                }
                Text("\(model.isEmpty ? "模型" : model) · \(log.userName.isEmpty ? "-" : log.userName) · 序号 \(log.requestSequence) · 已运行 \(runningDurationText(log))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("请求中")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.13))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RecentRequestsPanel: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "最近请求", actionTitle: "日志", action: { state.openCCH("/zh-CN/dashboard/logs") })

            if state.recentLogs.isEmpty {
                EmptyStateView(text: "暂无最近日志")
            } else {
                ForEach(state.recentLogs.prefix(5)) { log in
                    CompactLogRow(log: log)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ProviderHealthPanel: View {
    @ObservedObject var state: MonitorState

    var attentionProviders: [CCHProvider] {
        state.providers
            .filter { $0.health.circuitState.lowercased() != "closed" || $0.health.failureCount > 0 || !$0.isEnabled }
            .sorted {
                if $0.health.failureCount != $1.health.failureCount {
                    return $0.health.failureCount > $1.health.failureCount
                }
                return $0.name < $1.name
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "渠道健康", actionTitle: "打开", action: { state.openCCH("/zh-CN/dashboard/providers") })

            HStack(spacing: 8) {
                MiniStat(title: "启用", value: "\(state.enabledProviderCount)")
                MiniStat(title: "总数", value: "\(state.providers.count)")
            }

            if attentionProviders.isEmpty {
                HStack(spacing: 8) {
                    StatusDot(color: .green)
                    Text("已启用渠道状态正常")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(9)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(attentionProviders.prefix(5)) { provider in
                    CompactProviderRow(provider: provider)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .padding(11)
        .frame(width: 260)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct LeaderboardTabView: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("", selection: $state.leaderboardPeriod) {
                    ForEach(CCHLeaderboardPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 230)
                .onChange(of: state.leaderboardPeriod) { _, _ in
                    Task { await state.refreshLeaderboardOnly() }
                }

                Picker("", selection: $state.leaderboardScope) {
                    ForEach(CCHLeaderboardScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .onChange(of: state.leaderboardScope) { _, _ in
                    Task { await state.refreshLeaderboardOnly() }
                }

                Spacer()
                Button("打开") { state.openCCH("/zh-CN/dashboard/leaderboard") }
                    .buttonStyle(.borderless)
            }

            HStack(spacing: 10) {
                MiniStat(title: "请求", value: compactNumber(state.leaderboard.reduce(0) { $0 + $1.requests }))
                MiniStat(title: "成本", value: formatMoney(state.leaderboard.reduce(0) { $0 + $1.cost }))
                MiniStat(title: "Tokens", value: compactNumber(state.leaderboard.reduce(0) { $0 + $1.tokens }))
                MiniStat(
                    title: "缓存",
                    value: formatPercent(cacheHitRate(
                        cacheReadTokens: state.leaderboard.reduce(0) { $0 + $1.cacheReadTokens },
                        inputTokens: state.leaderboard.reduce(0) { $0 + $1.inputTokens }
                    ))
                )
                Spacer()
            }

            if state.leaderboard.isEmpty {
                EmptyStateView(text: "暂无排行数据")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(state.leaderboard.prefix(12).enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRow(rank: index + 1, entry: entry)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
            }
        }
    }
}

private struct LogsTabView: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Picker("", selection: $state.logRange) {
                    ForEach(CCHLogRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .onChange(of: state.logRange) { _, _ in
                    Task { await state.refreshLogsOnly() }
                }
                TextField("模型", text: $state.logModelFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                TextField("状态", text: $state.logStatusFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                TextField("session", text: $state.logSessionFilter)
                    .textFieldStyle(.roundedBorder)
                Button("应用") {
                    Task { await state.refreshLogsOnly() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 10) {
                MiniStat(title: "总数", value: compactNumber(state.logSummary.totalRequests))
                MiniStat(title: "成本", value: formatMoney(state.logSummary.totalCost))
                MiniStat(title: "Tokens", value: compactNumber(state.logSummary.totalTokens))
                MiniStat(title: "缓存", value: formatPercent(cacheHitRate(cacheReadTokens: state.logSummary.cacheReadTokens, inputTokens: state.logSummary.inputTokens)))
                MiniStat(title: "已载入", value: "\(state.logs.count)/\(state.logTotal)")
                Spacer()
                Button("打开") { state.openCCH("/zh-CN/dashboard/logs") }
                    .buttonStyle(.borderless)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 7) {
                    if state.logs.isEmpty {
                        EmptyStateView(text: "暂无日志")
                    } else {
                        ForEach(state.logs.prefix(18)) { log in
                            LogRow(log: log, isSelected: state.selectedLog?.id == log.id)
                                .onTapGesture {
                                    state.selectedLog = log
                                }
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                LogDetailView(log: state.selectedLog ?? state.logs.first)
                    .frame(width: 250)
            }
        }
    }
}

private struct ProvidersTabView: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MiniStat(title: "渠道", value: "\(state.filteredProviders.count)")
                MiniStat(title: "启用", value: "\(state.filteredEnabledProviderCount)")
                MiniStat(title: "异常", value: "\(state.filteredUnhealthyProviderCount)")
                Spacer()
                Button("打开") { state.openCCH("/zh-CN/dashboard/providers") }
                    .buttonStyle(.borderless)
            }

            ProviderGroupChips(state: state)

            if state.filteredProviders.isEmpty {
                EmptyStateView(text: "暂无渠道")
            } else {
                VStack(spacing: 8) {
                    ForEach(state.filteredProviders) { provider in
                        ProviderRow(state: state, provider: provider)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
            }
        }
    }
}

private struct ProviderGroupChips: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        HStack(spacing: 8) {
            Text("分组")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(state.providerGroups, id: \.self) { group in
                        Button {
                            state.toggleProviderGroup(group)
                        } label: {
                            let selected = state.isProviderGroupSelected(group)
                            Text(group)
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selected ? Color.orange.opacity(0.22) : Color(nsColor: .controlBackgroundColor).opacity(0.55))
                                .foregroundStyle(selected ? .orange : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 26)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.22), lineWidth: 1))
    }
}

private struct MiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MultiplierBadge: View {
    let value: Double
    var compact = false

    var color: Color {
        switch multiplierLevel(value) {
        case 0, 1: return .green
        case 2: return .orange
        default: return .red
        }
    }

    var body: some View {
        Text(formatMultiplier(value))
            .font(.system(size: compact ? 8.5 : 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 4 : 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.13))
            .clipShape(Capsule())
    }
}

private struct StatusCapsule: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

private struct ProviderTag: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

private struct HoverLink: View {
    let title: String
    let icon: String
    let url: URL
    @State private var isHovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isHovering ? Color.blue.opacity(0.16) : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? .blue : Color.blue.opacity(0.88))
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
            }
        }
    }
}

private struct ActiveSessionRow: View {
    let session: CCHActiveSession

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(color: session.concurrentCount > 0 ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.model.isEmpty ? session.apiType : session.model)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text("\(session.userName) · \(session.keyName) · \(session.providerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(session.requestCount)x")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(formatMoney(session.costUsd))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)
        }
        .padding(9)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let entry: CCHLeaderboardEntry

    var cacheColor: Color {
        entry.cacheHitRate == nil ? Color.secondary : Color.mint
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? .orange : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(compactNumber(entry.requests)) 次")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(compactNumber(entry.tokens))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(entry.cacheHitRate.map(formatPercent) ?? "-")
                .font(.caption)
                .foregroundStyle(cacheColor)
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)
            Text(formatMoney(entry.cost))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
        }
        .padding(9)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LogRow: View {
    let log: CCHLogEntry
    let isSelected: Bool

    var statusColor: Color {
        guard let code = log.statusCode else { return .secondary }
        if (200..<300).contains(code) { return .green }
        if code >= 500 { return .red }
        return .orange
    }

    var throughput: Double? {
        log.tokensPerSecond ?? computedTokensPerSecond(outputTokens: log.outputTokens, durationMs: log.durationMs, ttfbMs: log.ttfbMs)
    }

    var body: some View {
        HStack(spacing: 9) {
            LogStatusIndicator(color: statusColor, isRunning: log.statusCode == nil)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(log.model.isEmpty ? log.originalModel : log.model)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    StatusCapsule(text: log.statusCode.map(String.init) ?? "请求中", color: statusColor)
                }
                Text("\(shortTime(log.createdAt)) · \(log.userName) · \(log.providerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(formatMillisecondsAsSeconds(log.durationMs))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text("TTFB \(formatMillisecondsAsSeconds(log.ttfbMs))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(formatTokensPerSecond(throughput))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(width: 76, alignment: .trailing)
            Text(formatMoney(log.costUsd))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CompactLogRow: View {
    let log: CCHLogEntry

    var statusColor: Color {
        guard let code = log.statusCode else { return .green }
        if (200..<300).contains(code) { return .green }
        if code >= 500 { return .red }
        return .orange
    }

    var statusText: String {
        log.statusCode.map(String.init) ?? "请求中"
    }

    var model: String {
        log.model.isEmpty ? log.originalModel : log.model
    }

    var throughput: Double? {
        log.tokensPerSecond ?? computedTokensPerSecond(outputTokens: log.outputTokens, durationMs: log.durationMs, ttfbMs: log.ttfbMs)
    }

    var body: some View {
        HStack(spacing: 8) {
            LogStatusIndicator(color: statusColor, isRunning: log.statusCode == nil)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(log.providerName.isEmpty ? "渠道" : log.providerName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    MultiplierBadge(value: logProviderMultiplier(log), compact: true)
                }
                Text("\(model.isEmpty ? "模型" : model) · \(shortTime(log.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            StatusCapsule(text: statusText, color: statusColor)
                .frame(width: 50, alignment: .trailing)
            VStack(alignment: .trailing, spacing: 1) {
                Text(formatMillisecondsAsSeconds(log.durationMs))
                Text("TTFB \(formatMillisecondsAsSeconds(log.ttfbMs))")
                Text(formatTokensPerSecond(throughput))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .frame(width: 62, alignment: .trailing)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CompactProviderRow: View {
    let provider: CCHProvider

    var healthColor: Color {
        if provider.health.circuitState.lowercased() == "open" { return .red }
        if provider.health.failureCount > 0 { return .orange }
        return provider.isEnabled ? .green : .secondary
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(color: healthColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Text(provider.isEnabled ? "\(provider.health.circuitState) · 失败 \(provider.health.failureCount)" : "已停用")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            MultiplierBadge(value: provider.costMultiplier, compact: true)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LogDetailView: View {
    let log: CCHLogEntry?

    func throughput(_ log: CCHLogEntry) -> Double? {
        log.tokensPerSecond ?? computedTokensPerSecond(outputTokens: log.outputTokens, durationMs: log.durationMs, ttfbMs: log.ttfbMs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("详情")
                .font(.system(size: 13, weight: .semibold))
            if let log {
                DetailLine("Session ID", value: log.sessionId.isEmpty ? "-" : log.sessionId)
                DetailLine("端点", value: log.endpoint.isEmpty ? "-" : log.endpoint)
                DetailLine("Tokens", value: "\(compactNumber(log.totalTokens))  in \(compactNumber(log.inputTokens)) / out \(compactNumber(log.outputTokens))")
                DetailLine("缓存", value: "\(compactNumber(log.cacheCreationTokens)) 写 / \(compactNumber(log.cacheReadTokens)) 读")
                DetailLine("性能", value: "\(formatMillisecondsAsSeconds(log.durationMs)) · TTFB \(formatMillisecondsAsSeconds(log.ttfbMs)) · \(formatTokensPerSecond(throughput(log)))")
                if !log.errorMessage.isEmpty {
                    Text(log.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(4)
                }
                Divider().opacity(0.35)
                HStack {
                    Text("供应商决策链")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(attemptCount(log.providerChain))次")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
                if log.providerChain.isEmpty {
                    Text("-")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(log.providerChain.prefix(6)) { item in
                        ProviderChainRow(item: item)
                    }
                }
            } else {
                EmptyStateView(text: "选择一条日志")
            }
            Spacer()
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ProviderChainRow: View {
    let item: CCHProviderChainItem

    var statusColor: Color {
        guard let code = item.statusCode else {
            return item.reason.contains("error") || item.reason.contains("fail") ? .red : .secondary
        }
        if (200..<300).contains(code) { return .green }
        if code == 429 || code >= 500 { return .red }
        return .orange
    }

    var statusText: String {
        item.statusCode.map(String.init) ?? chainReasonTitle(item.reason)
    }

    var detail: String {
        let group = providerGroupTitle(item.groupTag)
        return "\(item.providerType) · \(group) · 优先级 \(item.priority) · 权重 \(item.weight)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            LogStatusIndicator(color: statusColor, isRunning: false)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(statusText)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                    MultiplierBadge(value: item.costMultiplier, compact: true)
                }
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !item.errorMessage.isEmpty {
                    Text(item.errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let attempt = item.attemptNumber {
                Text("#\(attempt)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProviderRow: View {
    @ObservedObject var state: MonitorState
    let provider: CCHProvider

    var healthColor: Color {
        if provider.health.circuitState.lowercased() == "open" { return .red }
        if provider.health.failureCount > 0 { return .orange }
        return provider.isEnabled ? .green : .secondary
    }

    var websiteURL: URL? {
        let raw = provider.websiteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.apiURL
            : provider.websiteURL
        return URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            StatusDot(color: healthColor)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(provider.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        ForEach(providerGroupTitles(provider.groupTag).prefix(2), id: \.self) { group in
                            ProviderTag(group, color: .purple)
                        }
                    }
                    HStack(spacing: 6) {
                        ProviderTag("优先级 \(provider.priority)", color: .secondary)
                        ProviderTag("权重 \(provider.weight)", color: .secondary)
                        MultiplierBadge(value: provider.costMultiplier, compact: true)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(provider.todayCalls) 次")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(formatMoney(provider.todayCost))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(width: 64, alignment: .trailing)
                Toggle("", isOn: Binding(
                    get: { provider.isEnabled },
                    set: { value in
                        Task { await state.setProvider(provider, enabled: value) }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.72)
                }
                HStack(spacing: 8) {
                    Text(provider.health.circuitState.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(healthColor)
                    if let websiteURL {
                        HoverLink(title: "官网", icon: "globe", url: websiteURL)
                    }
                    Text("失败 \(provider.health.failureCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(provider.limitText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("测速") {
                        Task { await state.probe(provider) }
                    }
                    .buttonStyle(.borderless)
                    if provider.health.circuitState.lowercased() == "open" {
                        Button("重置") {
                            Task { await state.resetCircuit(provider) }
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.35), radius: 3)
    }
}

private struct LogStatusIndicator: View {
    let color: Color
    let isRunning: Bool
    @State private var pulse = false

    var runningColor: Color {
        .blue
    }

    var body: some View {
        ZStack {
            if isRunning {
                Circle()
                    .stroke(runningColor.opacity(pulse ? 0 : 0.55), lineWidth: 1.4)
                    .frame(width: pulse ? 20 : 10, height: pulse ? 20 : 10)
                CCHTriangleMark()
                    .fill(runningColor)
                    .frame(width: 7, height: 8)
                    .offset(x: 0.5)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color.opacity(0.35), radius: 3)
            }
        }
        .frame(width: 18, height: 18)
        .onAppear {
            guard isRunning else { return }
            pulse = false
            withAnimation(.easeOut(duration: 1.05).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

private struct EmptyStateView: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 18)
            Spacer()
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func logProviderMultiplier(_ log: CCHLogEntry) -> Double {
    if let item = log.providerChain.reversed().first(where: { $0.name == log.providerName }) {
        return item.costMultiplier
    }
    if let item = log.providerChain.last {
        return item.costMultiplier
    }
    return 1
}

private func attemptCount(_ chain: [CCHProviderChainItem]) -> Int {
    let attempts = chain.compactMap(\.attemptNumber)
    if let maxAttempt = attempts.max(), maxAttempt > 0 {
        return maxAttempt
    }
    return chain.filter { $0.statusCode != nil }.count
}

private func chainReasonTitle(_ reason: String) -> String {
    switch reason {
    case "request_success": return "成功"
    case "request_error": return "失败"
    case "initial_selection": return "选择"
    case "session_reuse": return "复用"
    case "retry": return "重试"
    default:
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }
}
