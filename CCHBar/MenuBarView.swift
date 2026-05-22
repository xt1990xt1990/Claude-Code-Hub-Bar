import SwiftUI

private enum CCHPanelLayout {
    static let width: CGFloat = 760
    static let height: CGFloat = 630
    static let contentWidth: CGFloat = 732
    static let scrollHeight: CGFloat = 476
}

private extension Color {
    static let cchPanelBackgroundTop = Color(red: 0.135, green: 0.142, blue: 0.170)
    static let cchPanelBackgroundBottom = Color(red: 0.085, green: 0.090, blue: 0.115)
    static let cchGlassPanel = Color.white.opacity(0.085)
    static let cchGlassPanelSoft = Color.white.opacity(0.055)
    static let cchGlassRow = Color.white.opacity(0.065)
    static let cchUserAccent = Color.orange.opacity(0.95)
}

struct MoneyValue: View {
    let value: Double
    var majorSize: CGFloat
    var minorSize: CGFloat?
    var weight: Font.Weight
    var color: Color

    init(
        value: Double,
        majorSize: CGFloat,
        minorSize: CGFloat? = nil,
        weight: Font.Weight = .semibold,
        color: Color = .primary
    ) {
        self.value = value
        self.majorSize = majorSize
        self.minorSize = minorSize
        self.weight = weight
        self.color = color
    }

    var body: some View {
        let parts = moneyDisplayParts(value)
        let resolvedMinorSize = minorSize ?? max(6, majorSize * 0.55)
        HStack(alignment: .top, spacing: 0) {
            Text(parts.major)
                .font(.system(size: majorSize, weight: weight, design: .rounded))
                .monospacedDigit()
            if let minor = parts.minor {
                Text(minor)
                    .font(.system(size: resolvedMinorSize, weight: .bold, design: .rounded))
                    .baselineOffset(majorSize * 0.28)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
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

private enum ModelBrand: String {
    case openai
    case claude
    case deepseek
    case gemini

    var assetName: String {
        switch self {
        case .openai: return "model-openai"
        case .claude: return "model-claude"
        case .deepseek: return "model-deepseek"
        case .gemini: return "model-gemini"
        }
    }

    static func resolve(model: String, provider: String = "") -> ModelBrand? {
        let text = "\(model) \(provider)".lowercased()
        if text.contains("deepseek") { return .deepseek }
        if text.contains("gemini") || text.contains("google") { return .gemini }
        if text.contains("claude") || text.contains("anthropic") { return .claude }
        if text.contains("openai")
            || text.contains("codex")
            || text.contains("gpt")
            || text.contains("o1")
            || text.contains("o3")
            || text.contains("o4")
            || text.contains("o5") {
            return .openai
        }
        return nil
    }
}

private struct ModelBrandIcon: View {
    let model: String
    var provider: String = ""
    var size: CGFloat = 13

    var body: some View {
        if let brand = ModelBrand.resolve(model: model, provider: provider) {
            Image(brand.assetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        }
    }
}

private struct NewLogEdgeFlash: View {
    let active: Bool
    @State private var visible = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color.blue.opacity(visible ? 0.95 : 0))
            .frame(width: 2)
            .padding(.vertical, 6)
            .onAppear {
                guard active else { return }
                visible = true
                withAnimation(.easeOut(duration: 0.55)) {
                    visible = false
                }
            }
            .onChange(of: active) { _, newValue in
                guard newValue else {
                    visible = false
                    return
                }
                visible = true
                withAnimation(.easeOut(duration: 0.55)) {
                    visible = false
                }
            }
    }
}

private struct CCHSegmentedTabBar: View {
    @Binding var selection: CCHPanelTab
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CCHPanelTab.allCases) { tab in
                let isActive = selection == tab
                Button {
                    guard selection != tab else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background {
                        if isActive {
                            if #available(macOS 26.0, *) {
                                Color.clear
                                    .glassEffect(
                                        .regular.interactive(),
                                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    )
                                    .matchedGeometryEffect(id: "cchTabIndicator", in: indicatorNamespace)
                            } else {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(0.16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "cchTabIndicator", in: indicatorNamespace)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

struct MenuBarView: View {
    @ObservedObject var state: MonitorState
    @State private var builtTabs: Set<CCHPanelTab> = [.dashboard]

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(state: state)
            Divider().opacity(0.35)
            CCHSegmentedTabBar(selection: $state.selectedTab)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider().opacity(0.25)

            ZStack(alignment: .topLeading) {
                ForEach(CCHPanelTab.allCases) { tab in
                    Group {
                        if builtTabs.contains(tab) {
                            ScrollView {
                                Group {
                                    switch tab {
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
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: CCHPanelLayout.width, height: CCHPanelLayout.scrollHeight)
                    .opacity(state.selectedTab == tab ? 1 : 0)
                    .offset(x: tabSlideOffset(for: tab))
                    .allowsHitTesting(state.selectedTab == tab)
                }
            }
            .frame(width: CCHPanelLayout.width, height: CCHPanelLayout.scrollHeight)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: state.selectedTab)
            .onChange(of: state.selectedTab) { _, newTab in
                builtTabs.insert(newTab)
                Task {
                    try? await Task.sleep(nanoseconds: 220_000_000)
                    await state.refreshFocusedView()
                }
            }

            Divider().opacity(0.25)
            FooterView(state: state)
        }
        .frame(width: CCHPanelLayout.width, height: CCHPanelLayout.height, alignment: .top)
        .background {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(Color.clear)
                    .glassEffect(.clear, in: Rectangle())
                    .overlay {
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 1.2)
                            Spacer(minLength: 0)
                        }
                    }
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [
                            .cchPanelBackgroundTop.opacity(0.16),
                            .cchPanelBackgroundBottom.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 1.2)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.18), value: state.isLoading)
        .onAppear {
            state.setPanelVisible(true)
        }
        .onDisappear {
            state.setPanelVisible(false)
        }
    }

    private func tabSlideOffset(for tab: CCHPanelTab) -> CGFloat {
        let order = CCHPanelTab.allCases
        guard let current = order.firstIndex(of: state.selectedTab),
              let target = order.firstIndex(of: tab) else { return 0 }
        if target == current { return 0 }
        return target < current ? -8 : 8
    }
}

private struct HeaderView: View {
    @ObservedObject var state: MonitorState
    @State private var hoveringProjectLink = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                state.openCCH()
            } label: {
                CCHLogoMark(size: 28)
            }
            .buttonStyle(.plain)
            .help("打开 CCH")
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
            HStack(spacing: 10) {
                FooterStatusLine(state: state)
                Spacer(minLength: 8)
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
        .animation(.easeInOut(duration: 0.22), value: state.errorMessage)
        .animation(.easeInOut(duration: 0.22), value: state.actionMessage)
        .animation(.easeInOut(duration: 0.22), value: state.availableUpdate)
    }
}

private struct FooterStatusLine: View {
    @ObservedObject var state: MonitorState

    private enum Mode: Equatable {
        case error(String)
        case action(String)
        case update(String, URL)
        case stale(Int)
        case idle(String)
    }

    private func mode(at now: Date) -> Mode {
        if let error = state.errorMessage, !error.isEmpty {
            return .error(error)
        }
        if let action = state.actionMessage, !action.isEmpty {
            return .action(action)
        }
        if let update = state.availableUpdate {
            return .update("有新版本 v\(update.version)", update.releaseURL)
        }
        if let last = state.lastRefresh {
            let age = now.timeIntervalSince(last)
            if age > 30 {
                return .stale(Int(age))
            }
        }
        return .idle("v\(state.appVersion)")
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            content(for: mode(at: context.date))
        }
    }

    @ViewBuilder
    private func content(for mode: Mode) -> some View {
        Group {
            switch mode {
            case .error(let message):
                FooterStatusPill(icon: "exclamationmark.triangle.fill", text: message, color: .orange)
            case .action(let message):
                FooterStatusPill(icon: "checkmark.circle.fill", text: message, color: .green)
            case .update(let message, let url):
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    FooterStatusPill(icon: "arrow.down.circle.fill", text: message, color: .blue)
                }
                .buttonStyle(.plain)
                .help("点击查看版本说明")
            case .stale(let seconds):
                FooterStatusPill(icon: "exclamationmark.triangle.fill", text: "数据停滞 \(seconds)s", color: .orange)
            case .idle(let version):
                Text(version)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .id(modeId(for: mode))
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .move(edge: .top))
            )
        )
    }

    private func modeId(for mode: Mode) -> String {
        switch mode {
        case .error(let m): return "error:\(m)"
        case .action(let m): return "action:\(m)"
        case .update(let m, _): return "update:\(m)"
        case .stale: return "stale"
        case .idle: return "idle"
        }
    }
}

private struct FooterStatusPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.13))
        .clipShape(Capsule())
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

    private var cacheMetricColor: Color {
        state.hasCacheAlert ? .red : .mint
    }

    private var cacheMetricDetail: String {
        state.hasCacheAlert ? "缓存掉线" : "命中率"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RunningRequestsPanel(state: state)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                MetricCard(title: "成本", value: MoneyValue(value: state.overview.todayCost, majorSize: 23, minorSize: 12, weight: .bold), detail: "今日", color: .green, icon: "dollarsign.circle")
                MetricCard(title: "请求", value: compactNumber(state.overview.todayRequests), detail: "\(state.overview.recentMinuteRequests)/分钟", color: .cyan, icon: "bolt.horizontal.circle")
                MetricCard(title: "会话", value: "\(state.overview.concurrentSessions)", detail: "\(state.menuBarRunningLogs.count) 运行中", color: .purple, icon: "play.circle")
                MetricCard(title: "缓存", value: formatPercent(cacheHitRate(cacheReadTokens: state.logSummary.cacheReadTokens, inputTokens: state.logSummary.inputTokens)), detail: cacheMetricDetail, color: cacheMetricColor, icon: "memorychip")
            }

            HStack(alignment: .top, spacing: 12) {
                RecentRequestsPanel(state: state)
                DashboardLeaderboardPanel(state: state)
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
                        HStack(spacing: 4) {
                            Text("今日 \(compactNumber(state.overview.todayRequests)) 次请求 ·")
                            MoneyValue(value: state.overview.todayCost, majorSize: 11, minorSize: 6.5, weight: .semibold, color: .secondary)
                        }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(11)
                .background(Color.cchGlassRow)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(state.menuBarRunningLogs.prefix(4)) { log in
                    RunningRequestRow(state: state, log: log)
                        .transition(.opacity)
                }
            }
        }
        .padding(11)
        .background(Color.cchGlassPanel)
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
                    .frame(width: 8.8, height: 8.8)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(log.providerName.isEmpty ? "渠道" : log.providerName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .textAdaptiveWidth(log.providerName.isEmpty ? "渠道" : log.providerName, limit: 160, compactThreshold: 18)
                    MultiplierBadge(value: state.providerMultiplier(for: log.providerName))
                }
                HStack(spacing: 4) {
                    ModelBrandIcon(model: model, provider: log.providerName, size: 12)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(model.isEmpty ? "模型" : model)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textAdaptiveWidth(model.isEmpty ? "模型" : model, limit: 190, compactThreshold: 18)
                    Text("·")
                        .fixedSize(horizontal: true, vertical: false)
                    Text(log.userName.isEmpty ? "-" : log.userName)
                        .foregroundStyle(Color.cchUserAccent)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("· 序号 \(log.requestSequence) · 已运行 \(runningDurationText(log))")
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .layoutPriority(1)

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
                    CompactLogRow(
                        log: log,
                        cacheStatus: state.cacheStatus(for: log),
                        isNew: state.highlightedLogIds.contains(log.id)
                    )
                    .transition(.opacity)
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .background(Color.cchGlassPanel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DashboardLeaderboardPanel: View {
    @ObservedObject var state: MonitorState

    var accent: Color {
        switch state.leaderboardScope {
        case .user: return .orange
        case .provider: return .purple
        case .model: return .blue
        }
    }

    var title: String {
        "\(state.leaderboardScope.title)排行"
    }

    var maxCost: Double {
        max(state.leaderboard.prefix(12).map(\.cost).max() ?? 0, 0.01)
    }

    private var scopes: [CCHLeaderboardScope] {
        [.user, .provider, .model]
    }

    private func setScope(_ scope: CCHLeaderboardScope) {
        guard state.leaderboardScope != scope else { return }
        state.setLeaderboardScope(scope)
        Task { await state.refreshLeaderboardOnly() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(spacing: 4) {
                    ForEach(scopes) { scope in
                        let selected = state.leaderboardScope == scope
                        let scopeColor = leaderboardScopeColor(scope)
                        Button {
                            setScope(scope)
                        } label: {
                            Text(scope.title)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(selected ? scopeColor : Color.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(selected ? scopeColor.opacity(0.16) : Color.white.opacity(0.045))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(scopeColor.opacity(selected ? 0.38 : 0.12), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            if state.leaderboard.isEmpty {
                EmptyStateView(text: "暂无排行数据")
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(state.leaderboard.prefix(12).enumerated()), id: \.element.id) { index, entry in
                            DashboardLeaderboardRow(
                                rank: index + 1,
                                entry: entry,
                                accent: accent,
                                maxCost: maxCost,
                                cacheHitRate: state.leaderboardCacheHitRate(for: entry),
                                showsCache: entry.cacheHitRateOverride != nil
                            )
                        }
                    }
                    .padding(.trailing, 3)
                }
                .frame(height: 272)
            }
        }
        .padding(14)
        .frame(width: 292)
        .background(Color.cchGlassPanel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.18), lineWidth: 1))
    }
}

private func leaderboardScopeColor(_ scope: CCHLeaderboardScope) -> Color {
    switch scope {
    case .user: return .orange
    case .provider: return .purple
    case .model: return .blue
    }
}

private struct DashboardLeaderboardRow: View {
    let rank: Int
    let entry: CCHLeaderboardEntry
    let accent: Color
    let maxCost: Double
    let cacheHitRate: Double?
    let showsCache: Bool

    var rankColor: Color {
        switch rank {
        case 1: return .orange
        case 2: return .secondary
        default: return .red
        }
    }

    var progress: Double {
        min(1, max(0.035, entry.cost / maxCost))
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(rankColor.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(rankColor.opacity(0.35), lineWidth: 1))
                Image(systemName: rank == 1 ? "trophy.fill" : "medal.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(rankColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    MoneyValue(value: entry.cost, majorSize: 12, minorSize: 7, weight: .bold)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(accent)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 5)
                HStack {
                    Text("\(compactNumber(entry.requests)) 请求")
                    Text("\(compactNumber(entry.tokens)) Token")
                    Spacer()
                    if showsCache, let cacheHitRate {
                        Text("缓存 \(formatPercent(cacheHitRate))")
                            .foregroundStyle(cacheRateColor(cacheHitRate))
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
            }
        }
    }
}

private struct LeaderboardTabView: View {
    @ObservedObject var state: MonitorState

    var accent: Color {
        leaderboardScopeColor(state.leaderboardScope)
    }

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
                MiniStat(title: "请求", value: Text(compactNumber(state.leaderboardSummary.requests)).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                MiniStat(title: "成本", value: MoneyValue(value: state.leaderboardSummary.cost, majorSize: 14, minorSize: 8, weight: .bold))
                MiniStat(title: "Tokens", value: Text(compactNumber(state.leaderboardSummary.tokens)).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                if let cacheHitRate = state.leaderboardSummary.cacheHitRate {
                    MiniStat(
                        title: "缓存",
                        value: Text(formatPercent(cacheHitRate))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    )
                }
                Spacer()
            }

            if state.leaderboard.isEmpty {
                EmptyStateView(text: "暂无排行数据")
                    .frame(width: CCHPanelLayout.contentWidth, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(state.leaderboard.prefix(12).enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRow(
                            state: state,
                            rank: index + 1,
                            entry: entry,
                            cacheHitRate: state.leaderboardCacheHitRate(for: entry),
                            showsCache: entry.cacheHitRateOverride != nil,
                            accent: accent
                        )
                    }
                }
                .frame(width: CCHPanelLayout.contentWidth, alignment: .topLeading)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .frame(width: CCHPanelLayout.contentWidth, alignment: .topLeading)
        .animation(nil, value: state.leaderboard.map(\.id))
        .animation(nil, value: state.leaderboardScope)
    }
}

private struct LogsTabView: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("近 1 小时", systemImage: "clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
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
                MiniStat(title: "总数", value: Text(compactNumber(state.logSummary.totalRequests)).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                MiniStat(title: "成本", value: MoneyValue(value: state.logSummary.totalCost, majorSize: 14, minorSize: 8, weight: .bold))
                MiniStat(title: "Tokens", value: Text(compactNumber(state.logSummary.totalTokens)).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                MiniStat(title: "缓存", value: Text(formatPercent(cacheHitRate(cacheReadTokens: state.logSummary.cacheReadTokens, inputTokens: state.logSummary.inputTokens))).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                MiniStat(title: "已载入", value: Text("\(state.logs.count)/\(state.logTotal)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                Spacer()
                Button("打开") { state.openCCH("/zh-CN/dashboard/logs") }
                    .buttonStyle(.borderless)
            }

            HStack(alignment: .top, spacing: 12) {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        if state.logs.isEmpty {
                            EmptyStateView(text: "暂无日志")
                        } else {
                            ForEach(state.logs) { log in
                                LogRow(
                                    log: log,
                                    isSelected: state.selectedLog?.id == log.id,
                                    cacheStatus: state.cacheStatus(for: log),
                                    isNew: state.highlightedLogIds.contains(log.id)
                                )
                                    .onTapGesture {
                                        state.selectedLog = log
                                    }
                                    .transition(.opacity)
                            }

                            if state.logs.count < state.logTotal {
                                Button {
                                    Task { await state.loadMoreLogs() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if state.isLoadingMoreLogs {
                                            ProgressView()
                                                .scaleEffect(0.62)
                                        }
                                        Text(state.isLoadingMoreLogs ? "加载中" : "加载更多")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("\(state.logs.count)/\(state.logTotal)")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(Color.cchGlassPanelSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(state.isLoadingMoreLogs)
                            }
                        }
                    }
                    .padding(.trailing, 3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 346)

                LogDetailView(log: state.selectedLog ?? state.logs.first)
                    .frame(width: 230)
            }
        }
    }
}

private struct ProvidersTabView: View {
    @ObservedObject var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MiniStat(title: "渠道", value: Text("\(state.filteredProviders.count)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                MiniStat(title: "启用", value: Text("\(state.filteredEnabledProviderCount)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                MiniStat(title: "异常", value: Text("\(state.filteredUnhealthyProviderCount)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit())
                Spacer()
                Button("打开") { state.openCCH("/zh-CN/dashboard/providers") }
                    .buttonStyle(.borderless)
            }

            ProviderGroupChips(state: state)

            if state.filteredProviders.isEmpty {
                EmptyStateView(text: "暂无渠道")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(state.filteredProviders) { provider in
                        ProviderRow(
                            provider: provider,
                            setEnabled: { value in
                                Task { await state.setProvider(provider, enabled: value) }
                            },
                            probe: {
                                Task { await state.probe(provider) }
                            },
                            resetCircuit: {
                                Task { await state.resetCircuit(provider) }
                            }
                        )
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
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
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                state.toggleProviderGroup(group)
                            }
                        } label: {
                            let selected = state.isProviderGroupSelected(group)
                            let color = group == "全部" ? Color.blue : providerGroupColor(group)
                            HStack(spacing: 4) {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .black))
                                        .transition(.scale.combined(with: .opacity))
                                }
                                Text(group)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10.5, weight: selected ? .bold : .semibold))
                            .padding(.horizontal, selected ? 10 : 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(selected ? color.opacity(0.34) : color.opacity(0.12))
                            )
                            .foregroundStyle(selected ? Color.white : color.opacity(0.92))
                            .overlay(
                                Capsule()
                                    .stroke(color.opacity(selected ? 0.88 : 0.28), lineWidth: selected ? 1.4 : 1)
                            )
                            .shadow(color: selected ? color.opacity(0.26) : .clear, radius: selected ? 5 : 0, y: 1)
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
    let value: AnyView
    let detail: String
    let color: Color
    let icon: String

    init(title: String, value: String, detail: String, color: Color, icon: String) {
        self.title = title
        self.value = AnyView(
            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .monospacedDigit()
        )
        self.detail = detail
        self.color = color
        self.icon = icon
    }

    init<V: View>(title: String, value: V, detail: String, color: Color, icon: String) {
        self.title = title
        self.value = AnyView(value)
        self.detail = detail
        self.color = color
        self.icon = icon
    }

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
            value
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.cchGlassPanel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.22), lineWidth: 1))
    }
}

private struct MiniStat: View {
    let title: String
    let value: AnyView

    init(title: String, value: String) {
        self.title = title
        self.value = AnyView(
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
        )
    }

    init<V: View>(title: String, value: V) {
        self.title = title
        self.value = AnyView(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            value
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.cchGlassPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct UsageMetricColumn: View {
    let top: Int
    let bottom: Int
    let topColor: Color
    let bottomColor: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(top > 0 ? compactNumber(top) : "-")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(top > 0 ? topColor : .secondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(bottom > 0 ? compactNumber(bottom) : "-")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(bottom > 0 ? bottomColor : .secondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct CompactUsageMetric: View {
    let title: String
    let top: Int
    let bottom: Int
    let topColor: Color
    let bottomColor: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(.secondary)
            Text(top > 0 ? compactNumber(top) : "-")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(top > 0 ? topColor : .secondary)
                .monospacedDigit()
            Text(bottom > 0 ? compactNumber(bottom) : "-")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(bottom > 0 ? bottomColor : .secondary.opacity(0.7))
                .monospacedDigit()
        }
        .frame(width: 42, alignment: .trailing)
    }
}

private struct AdaptiveTextWidth: ViewModifier {
    let textLength: Int
    let limit: CGFloat
    let compactThreshold: Int

    func body(content: Content) -> some View {
        if textLength <= compactThreshold {
            content
                .fixedSize(horizontal: true, vertical: false)
        } else {
            content
                .frame(maxWidth: limit, alignment: .leading)
        }
    }
}

private extension View {
    func textAdaptiveWidth(_ text: String, limit: CGFloat, compactThreshold: Int = 18) -> some View {
        modifier(AdaptiveTextWidth(textLength: text.count, limit: limit, compactThreshold: compactThreshold))
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
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct FastTierBadge: View {
    var body: some View {
        Text("FAST")
            .font(.system(size: 8.5, weight: .bold, design: .rounded))
            .foregroundStyle(.orange)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.orange.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.orange.opacity(0.24), lineWidth: 0.7))
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
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.18))
            .overlay(Capsule().stroke(color.opacity(0.26), lineWidth: 1))
            .clipShape(Capsule())
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
                HStack(spacing: 5) {
                    ModelBrandIcon(model: session.model.isEmpty ? session.apiType : session.model, provider: session.providerName, size: 13)
                    Text(session.model.isEmpty ? session.apiType : session.model)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
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
            MoneyValue(value: session.costUsd, majorSize: 12, minorSize: 7, weight: .semibold)
                .frame(width: 62, alignment: .trailing)
        }
        .padding(9)
        .background(Color.cchGlassRow)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LeaderboardRow: View {
    @ObservedObject var state: MonitorState
    let rank: Int
    let entry: CCHLeaderboardEntry
    let cacheHitRate: Double?
    let showsCache: Bool
    let accent: Color

    var isExpanded: Bool {
        state.expandedLeaderboardEntryId == entry.id
    }

    var canExpand: Bool {
        !entry.modelStats.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                guard canExpand else { return }
                state.expandedLeaderboardEntryId = isExpanded ? nil : entry.id
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accent.opacity(rank <= 3 ? 0.24 : 0.15))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(rank <= 3 ? 0.42 : 0.24), lineWidth: 1))
                        Text("\(rank)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(rank <= 3 ? accent : accent.opacity(0.82))
                    }
                    .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            if state.leaderboardScope == .model {
                                ModelBrandIcon(model: entry.title, provider: entry.subtitle, size: 13)
                            }
                            Text(entry.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if canExpand {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            }
                        }
                        Text(entry.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Text("\(compactNumber(entry.requests)) 次")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 64, alignment: .trailing)
                    Text(compactNumber(entry.tokens))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                    if showsCache, let cacheHitRate {
                        Text(formatPercent(cacheHitRate))
                            .font(.caption)
                            .foregroundStyle(cacheRateColor(cacheHitRate))
                            .monospacedDigit()
                            .frame(width: 58, alignment: .trailing)
                    }
                    MoneyValue(value: entry.cost, majorSize: 12, minorSize: 7, weight: .semibold)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(9)
                .background(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.16),
                            Color.white.opacity(0.050)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 5) {
                    ForEach(entry.modelStats.prefix(8)) { stat in
                        LeaderboardModelStatRow(stat: stat)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 9)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: CCHPanelLayout.contentWidth, alignment: .leading)
        .background(Color.cchGlassRow)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.16), lineWidth: 1))
        .animation(.easeInOut(duration: 0.16), value: isExpanded)
    }
}

private struct LeaderboardModelStatRow: View {
    let stat: CCHLeaderboardModelStat

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ModelBrandIcon(model: stat.model, size: 12)
                Text(stat.model)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text("\(compactNumber(stat.requests)) 次")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
            Text(compactNumber(stat.tokens))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)
            if let cacheHitRate = stat.cacheHitRate {
                Text(formatPercent(cacheHitRate))
                    .font(.caption2)
                    .foregroundStyle(cacheRateColor(cacheHitRate))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            MoneyValue(value: stat.cost, majorSize: 10.5, minorSize: 6.2, weight: .semibold)
                .frame(width: 62, alignment: .trailing)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.04)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct LogRow: View {
    let log: CCHLogEntry
    let isSelected: Bool
    let cacheStatus: CCHCacheStatusContext
    let isNew: Bool

    var statusColor: Color {
        guard let code = log.statusCode else { return .secondary }
        if (200..<300).contains(code) { return .green }
        if code >= 500 { return .red }
        return .orange
    }

    var throughput: Double? {
        normalizedTokensPerSecond(
            raw: log.tokensPerSecond,
            outputTokens: log.outputTokens,
            durationMs: log.durationMs,
            ttfbMs: log.ttfbMs
        )
    }

    var model: String {
        log.model.isEmpty ? log.originalModel : log.model
    }

    var body: some View {
        HStack(spacing: 9) {
            LogStatusIndicator(color: statusColor, isRunning: log.statusCode == nil)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    ModelBrandIcon(model: model, provider: log.providerName, size: 13)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(model)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if log.isFastTier {
                        FastTierBadge()
                    }
                    MultiplierBadge(value: logProviderMultiplier(log), compact: true)
                    StatusCapsule(text: log.statusCode.map(String.init) ?? "请求中", color: statusColor)
                }
                HStack(spacing: 4) {
                    Text(log.userName.isEmpty ? "-" : log.userName)
                        .foregroundStyle(Color.cchUserAccent)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("·")
                        .fixedSize(horizontal: true, vertical: false)
                    Text(log.providerName.isEmpty ? "渠道" : log.providerName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textAdaptiveWidth(log.providerName.isEmpty ? "渠道" : log.providerName, limit: 160, compactThreshold: 18)
                    Text("· \(shortTime(log.createdAt))")
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            Spacer()
            UsageMetricColumn(
                top: log.outputTokens,
                bottom: log.inputTokens,
                topColor: .primary,
                bottomColor: .secondary
            )
            .frame(width: 48, alignment: .trailing)
            UsageMetricColumn(
                top: log.cacheCreationTokens,
                bottom: log.cacheReadTokens,
                topColor: cacheCreationDisplayColor(cacheStatus),
                bottomColor: cacheReadDisplayColor(cacheStatus)
            )
            .frame(width: 56, alignment: .trailing)
            MoneyValue(value: log.costUsd, majorSize: 11.5, minorSize: 6.8, weight: .semibold)
                .frame(width: 62, alignment: .trailing)
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
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .overlay(alignment: .leading) {
            NewLogEdgeFlash(active: isNew)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CompactLogRow: View {
    let log: CCHLogEntry
    let cacheStatus: CCHCacheStatusContext
    let isNew: Bool

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
        normalizedTokensPerSecond(
            raw: log.tokensPerSecond,
            outputTokens: log.outputTokens,
            durationMs: log.durationMs,
            ttfbMs: log.ttfbMs
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            LogStatusIndicator(color: statusColor, isRunning: log.statusCode == nil)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(log.providerName.isEmpty ? "渠道" : log.providerName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                        .textAdaptiveWidth(log.providerName.isEmpty ? "渠道" : log.providerName, limit: 150, compactThreshold: 18)
                    MultiplierBadge(value: logProviderMultiplier(log), compact: true)
                    if log.isFastTier {
                        FastTierBadge()
                    }
                }
                HStack(spacing: 4) {
                    Text(log.userName.isEmpty ? "-" : log.userName)
                        .foregroundStyle(Color.cchUserAccent)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(3)
                    Text("·")
                        .fixedSize(horizontal: true, vertical: false)
                    ModelBrandIcon(model: model, provider: log.providerName, size: 11)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(model.isEmpty ? "模型" : model)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textAdaptiveWidth(model.isEmpty ? "模型" : model, limit: 130, compactThreshold: 10)
                    Text("· \(shortTime(log.createdAt))")
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            Spacer()
            CompactUsageMetric(
                title: "TOK",
                top: log.outputTokens,
                bottom: log.inputTokens,
                topColor: .primary,
                bottomColor: .secondary
            )
            CompactUsageMetric(
                title: "CACHE",
                top: log.cacheCreationTokens,
                bottom: log.cacheReadTokens,
                topColor: cacheCreationDisplayColor(cacheStatus),
                bottomColor: cacheReadDisplayColor(cacheStatus)
            )
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
            .frame(width: 58, alignment: .trailing)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .overlay(alignment: .leading) {
            NewLogEdgeFlash(active: isNew)
        }
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
                HStack(spacing: 5) {
                    ModelBrandIcon(
                        model: "\(provider.lastCallModel) \(provider.allowedModels)",
                        provider: "\(provider.providerType) \(provider.name)",
                        size: 12
                    )
                    Text(provider.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                }
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
        normalizedTokensPerSecond(
            raw: log.tokensPerSecond,
            outputTokens: log.outputTokens,
            durationMs: log.durationMs,
            ttfbMs: log.ttfbMs
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("详情")
                .font(.system(size: 13, weight: .semibold))
            if let log {
                DetailLine("Session ID", value: log.sessionId.isEmpty ? "-" : log.sessionId)
                DetailLine("端点", value: log.endpoint.isEmpty ? "-" : log.endpoint)
                DetailLine("倍率", value: formatMultiplier(logProviderMultiplier(log)))
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
                        .background(Color.cchGlassRow)
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
        .background(Color.cchGlassPanel)
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
                    ModelBrandIcon(model: item.providerType, provider: item.name, size: 12)
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
    let provider: CCHProvider
    let setEnabled: (Bool) -> Void
    let probe: () -> Void
    let resetCircuit: () -> Void

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
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            ModelBrandIcon(
                                model: "\(provider.lastCallModel) \(provider.allowedModels)",
                                provider: "\(provider.providerType) \(provider.name)",
                                size: 13
                            )
                            Text(provider.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            ForEach(providerGroupTitles(provider.groupTag).prefix(2), id: \.self) { group in
                                ProviderTag(group, color: providerGroupColor(group))
                            }
                        }
                        HStack(spacing: 6) {
                            ProviderTag("优先级 \(provider.priority)", color: .secondary)
                            ProviderTag("权重 \(provider.weight)", color: .secondary)
                            MultiplierBadge(value: provider.costMultiplier, compact: true)
                        }
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(provider.todayCalls) 次")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        MoneyValue(value: provider.todayCost, majorSize: 10.5, minorSize: 6.2, weight: .semibold, color: .secondary)
                    }
                    .frame(width: 64, alignment: .trailing)
                    Toggle("", isOn: Binding(
                        get: { provider.isEnabled },
                        set: { value in
                            setEnabled(value)
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
                        probe()
                    }
                    .buttonStyle(.borderless)
                    if provider.health.circuitState.lowercased() == "open" {
                        Button("重置") {
                            resetCircuit()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.cchGlassRow)
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
                    .frame(width: 18, height: 18)
                CCHTriangleMark()
                    .fill(runningColor)
                    .frame(width: 8, height: 8)
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
        .background(Color.cchGlassRow)
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

private func cacheCreationDisplayColor(_ status: CCHCacheStatusContext) -> Color {
    switch status.state {
    case .rebuilding:
        return .red
    case .normal:
        return status.createdTokens > 0 ? .green : .secondary
    }
}

private func cacheReadDisplayColor(_ status: CCHCacheStatusContext) -> Color {
    switch status.state {
    case .rebuilding:
        return .red
    case .normal:
        return status.readTokens > 0 ? .green : .secondary
    }
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
