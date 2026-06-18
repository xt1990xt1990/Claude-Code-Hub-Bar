import Combine
import SwiftUI

private enum CCHPanelLayout {
    static let width: CGFloat = 760
    static let height: CGFloat = 630
    static let contentWidth: CGFloat = 732
    static let scrollHeight: CGFloat = 476
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
        .contentTransition(.numericText())
        .animation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.24), value: value)
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
    @Environment(\.cchTheme) private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(theme.accentBlue.opacity(visible ? 0.95 : 0))
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

private struct CCHMicroRevealModifier: ViewModifier {
    let active: Bool
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(active ? (visible ? 1 : 0.72) : 1)
            .offset(y: active ? (visible ? 0 : 4) : 0)
            .scaleEffect(active ? (visible ? 1 : 0.985) : 1)
            .onAppear {
                guard active else {
                    visible = true
                    return
                }
                play()
            }
            .onChange(of: active) { _, newValue in
                if newValue {
                    play()
                } else {
                    visible = true
                }
            }
    }

    private func play() {
        visible = false
        withAnimation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.28)) {
            visible = true
        }
    }
}

private struct CCHProgressShimmer: View {
    let color: Color
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.52),
                    color.opacity(0.92),
                    Color.white.opacity(0.52),
                    Color.white.opacity(0.0),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: max(54, proxy.size.width * 0.42), height: proxy.size.height)
            .offset(x: phase * proxy.size.width)
            .blendMode(.screen)
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .onAppear {
            phase = -0.55
            withAnimation(.linear(duration: 0.92).repeatForever(autoreverses: false)) {
                phase = 1.18
            }
        }
        .onDisappear {
            phase = -0.55
        }
    }
}

extension View {
    func cchMicroReveal(active: Bool = true) -> some View {
        modifier(CCHMicroRevealModifier(active: active))
    }
}

private struct CCHSegmentedTabBar: View {
    @Binding var selection: CCHPanelTab
    @Namespace private var indicatorNamespace
    @Environment(\.cchTheme) private var theme
    private let tabAnimation = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.34)

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CCHPanelTab.allCases) { tab in
                let isActive = selection == tab
                Button {
                    guard selection != tab else { return }
                    withAnimation(tabAnimation) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(isActive && theme.prefersGlassEffects ? Color.white : (isActive ? theme.textPrimary : theme.textSecondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background {
                        if isActive {
                            if #available(macOS 26.0, *), theme.prefersGlassEffects {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(theme.accentBlue)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                                    )
                                    .matchedGeometryEffect(id: "cchTabIndicator", in: indicatorNamespace)
                            } else {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(theme.controlHover)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(theme.borderStrong, lineWidth: 0.5)
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
                .fill(theme.control)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(theme.border, lineWidth: 0.5)
                )
        )
    }
}

struct MenuBarView: View {
    @ObservedObject var state: MonitorState
    @State private var builtTabs: Set<CCHPanelTab>
    @State private var previousTab: CCHPanelTab
    @State private var transitioningTab: CCHPanelTab?
    private var theme: CCHThemePalette { state.selectedTheme.palette }
    private let pageTransitionAnimation = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.34)

    init(state: MonitorState) {
        self.state = state
        _builtTabs = State(initialValue: Set(CCHPanelTab.allCases))
        _previousTab = State(initialValue: state.selectedTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(state: state)
                .background(theme.headerBackground)
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
                                    case .upstreamRates:
                                        UpstreamRatesTabView(state: state)
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
                    .opacity(tabOpacity(for: tab))
                    .offset(x: tabSlideOffset(for: tab))
                    .allowsHitTesting(state.selectedTab == tab)
                }
            }
            .frame(width: CCHPanelLayout.width, height: CCHPanelLayout.scrollHeight)
            .clipped()
            .animation(pageTransitionAnimation, value: state.selectedTab)
            .animation(pageTransitionAnimation, value: transitioningTab)
            .onChange(of: state.selectedTab) { oldTab, newTab in
                previousTab = oldTab
                transitioningTab = oldTab
                Task {
                    try? await Task.sleep(nanoseconds: 340_000_000)
                    await state.refreshFocusedView()
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 340_000_000)
                    if state.selectedTab == newTab {
                        transitioningTab = nil
                        previousTab = newTab
                    }
                }
            }

            Divider().opacity(0.25)
            FooterView(state: state)
                .background(theme.footerBackground)
        }
        .frame(width: CCHPanelLayout.width, height: CCHPanelLayout.height, alignment: .top)
        .background {
            if #available(macOS 26.0, *), theme.prefersGlassEffects {
                Rectangle()
                    .fill(Color.clear)
                    .glassEffect(.clear, in: Rectangle())
                    .overlay {
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [theme.topHighlight, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 1.2)
                            Spacer(minLength: 0)
                        }
                    }
            } else {
                ZStack {
                    if theme.prefersGlassEffects {
                        Rectangle().fill(.ultraThinMaterial)
                    } else {
                        LinearGradient(
                            colors: [theme.backgroundTop, theme.backgroundBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    LinearGradient(
                        colors: [
                            theme.backgroundOverlayTop,
                            theme.backgroundOverlayBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [theme.topHighlight, Color.clear],
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
                .strokeBorder(theme.border, lineWidth: 1)
        )
        .foregroundStyle(theme.textPrimary)
        .environment(\.cchTheme, theme)
        .tint(theme.accentBlue)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.18), value: state.isLoading)
        .onAppear {
            builtTabs.insert(state.selectedTab)
            state.setPanelVisible(true)
        }
        .onDisappear {
            state.setPanelVisible(false)
        }
    }

    private func tabOpacity(for tab: CCHPanelTab) -> Double {
        if tab == state.selectedTab { return 1 }
        if tab == transitioningTab { return 0 }
        return 0
    }

    private func tabSlideOffset(for tab: CCHPanelTab) -> CGFloat {
        let order = CCHPanelTab.allCases
        guard let previous = order.firstIndex(of: previousTab),
              let current = order.firstIndex(of: state.selectedTab),
              let target = order.firstIndex(of: tab) else { return 0 }
        if target == current { return 0 }
        let direction: CGFloat = current >= previous ? 1 : -1
        if tab == transitioningTab {
            return -44 * direction
        }
        return 44 * direction
    }
}

private struct HeaderView: View {
    @ObservedObject var state: MonitorState
    @State private var hoveringProjectLink = false
    @Environment(\.cchTheme) private var theme

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
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Code Hub")
                    .font(.system(size: 15, weight: .semibold))
                Text("总览 · 日志 · 渠道")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
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
    @Environment(\.cchTheme) private var theme
    @State private var visibleMode: Mode?
    @State private var incomingMode: Mode?
    @State private var rollProgress: CGFloat = 1
    @State private var rollGeneration = 0
    @State private var now = Date()

    private let rollHeight: CGFloat = 24
    private let rollDuration: TimeInterval = 0.28
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private enum Mode: Equatable {
        case error(String)
        case action(String, Bool)
        case update(String, URL)
        case stale(Int)
        case idle(String)
    }

    private func mode(at now: Date) -> Mode {
        if let error = state.errorMessage, !error.isEmpty {
            return .error(error)
        }
        if let action = state.actionMessage, !action.isEmpty {
            return .action(action, state.actionMessageIsWarning)
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
        let currentMode = mode(at: now)
        let currentModeId = modeId(for: currentMode)

        ZStack(alignment: .leading) {
            if let visibleMode {
                content(for: visibleMode)
                    .offset(y: incomingMode == nil ? 0 : -rollProgress * rollHeight)
            }
            if let incomingMode {
                content(for: incomingMode)
                    .offset(y: (1 - rollProgress) * rollHeight)
            }
        }
        .frame(height: rollHeight, alignment: .leading)
        .clipped()
        .onAppear {
            let appearedAt = Date()
            now = appearedAt
            if visibleMode == nil {
                visibleMode = mode(at: appearedAt)
            }
        }
        .onDisappear {
            rollGeneration += 1
        }
        .onReceive(ticker) { date in
            guard state.panelVisible else { return }
            now = date
        }
        .onChange(of: state.lastRefresh) { _, _ in
            now = Date()
        }
        .onChange(of: currentModeId) { _, _ in
            roll(to: currentMode)
        }
    }

    @ViewBuilder
    private func content(for mode: Mode) -> some View {
        Group {
            switch mode {
            case .error(let message):
                FooterStatusPill(icon: "exclamationmark.triangle.fill", text: message, color: theme.accentOrange)
            case .action(let message, let isWarning):
                FooterStatusPill(
                    icon: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                    text: message,
                    color: isWarning ? theme.accentOrange : theme.accentGreen
                )
            case .update(let message, let url):
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    FooterStatusPill(icon: "arrow.down.circle.fill", text: message, color: theme.accentBlue)
                }
                .buttonStyle(.plain)
                .help("点击查看版本说明")
            case .stale(let seconds):
                FooterStatusPill(icon: "exclamationmark.triangle.fill", text: "数据停滞 \(seconds)s", color: theme.accentOrange)
            case .idle(let version):
                Text(version)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func modeId(for mode: Mode) -> String {
        switch mode {
        case .error(let m): return "error:\(m)"
        case .action(let m, let isWarning): return "action:\(isWarning ? "warning" : "success"):\(m)"
        case .update(let m, _): return "update:\(m)"
        case .stale(let seconds): return "stale:\(seconds)"
        case .idle: return "idle"
        }
    }

    private func roll(to mode: Mode) {
        guard visibleMode != nil else {
            visibleMode = mode
            incomingMode = nil
            rollProgress = 1
            return
        }

        if let visibleMode, modeId(for: visibleMode) == modeId(for: mode), incomingMode == nil {
            return
        }

        rollGeneration += 1
        let generation = rollGeneration

        if let incomingMode {
            visibleMode = incomingMode
        }
        incomingMode = mode
        rollProgress = 0

        withAnimation(.easeInOut(duration: rollDuration)) {
            rollProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration) {
            guard rollGeneration == generation else { return }
            visibleMode = mode
            incomingMode = nil
            rollProgress = 1
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
    @Environment(\.cchTheme) private var theme

    var color: Color {
        role == .destructive ? theme.accentRed : theme.accentBlue
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
            .background(hovering ? color.opacity(0.16) : theme.control)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(hovering ? 0.35 : 0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? color : (hovering ? color : theme.textSecondary))
        .onHover { isHovering in
            hovering = isHovering
        }
    }
}

private struct DashboardTabView: View {
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme

    private var cacheMetricColor: Color {
        state.hasCacheAlert ? theme.accentRed : theme.accentMint
    }

    private var cacheMetricDetail: String {
        state.hasCacheAlert ? "缓存掉线" : "命中率"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RunningRequestsPanel(state: state)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                MetricCard(title: "成本", value: MoneyValue(value: state.overview.todayCost, majorSize: 23, minorSize: 12, weight: .bold), detail: "今日", color: theme.accentGreen, icon: "dollarsign.circle")
                MetricCard(title: "请求", value: compactNumber(state.overview.todayRequests), detail: "\(state.overview.recentMinuteRequests)/分钟", color: theme.accentBlue, icon: "bolt.horizontal.circle")
                MetricCard(title: "会话", value: "\(state.overview.concurrentSessions)", detail: "\(state.menuBarRunningLogs.count) 运行中", color: theme.accentPurple, icon: "play.circle")
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
    @Environment(\.cchTheme) private var theme
    private let maxVisibleRows = 3
    private let rowHeight: CGFloat = 58
    private let rowSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(
                title: state.menuBarRunningLogs.isEmpty ? "暂无运行请求" : "运行中请求",
                actionTitle: "打开",
                action: { state.openCCH("/zh-CN/dashboard/logs") }
            )

            if state.menuBarRunningLogs.isEmpty {
                HStack(spacing: 10) {
                    StatusDot(color: theme.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("空闲")
                            .font(.system(size: 13, weight: .semibold))
                        HStack(spacing: 4) {
                            Text("今日 \(compactNumber(state.overview.todayRequests)) 次请求 ·")
                            MoneyValue(value: state.overview.todayCost, majorSize: 11, minorSize: 6.5, weight: .semibold, color: theme.textSecondary)
                        }
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(11)
                .cchSurface(.row)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ScrollView(.vertical, showsIndicators: state.menuBarRunningLogs.count > maxVisibleRows) {
                        LazyVStack(spacing: rowSpacing) {
                            ForEach(state.menuBarRunningLogs) { log in
                                RunningRequestRow(state: state, log: log)
                                    .frame(height: rowHeight)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    .cchMicroReveal(active: true)
                            }
                        }
                    }
                    .frame(height: runningListHeight)

                    if state.menuBarRunningLogs.count > maxVisibleRows {
                        Text("还有 \(state.menuBarRunningLogs.count - maxVisibleRows) 个运行中，请在列表内滚动查看")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(11)
        .cchSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderSubtle, lineWidth: 1))
    }

    private var runningListHeight: CGFloat {
        let visibleRows = min(maxVisibleRows, state.menuBarRunningLogs.count)
        let spacing = max(0, visibleRows - 1)
        return CGFloat(visibleRows) * rowHeight + CGFloat(spacing) * rowSpacing
    }
}

private struct RunningRequestRow: View {
    @ObservedObject var state: MonitorState
    let log: CCHLogEntry
    @Environment(\.cchTheme) private var theme

    var model: String {
        log.model.isEmpty ? log.originalModel : log.model
    }

    func runningDurationText(_ log: CCHLogEntry) -> String {
        guard let date = parseCCHDate(log.createdAt) else { return "--" }
        return formatDuration(Date().timeIntervalSince(date))
    }

    var body: some View {
        HStack(spacing: 10) {
            RunningSessionIndicator()

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(log.providerName.isEmpty ? "渠道" : log.providerName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .textAdaptiveWidth(log.providerName.isEmpty ? "渠道" : log.providerName, limit: 160, compactThreshold: 18)
                    MultiplierBadge(value: log.costMultiplier)
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
                        .cchUserAccent()
                        .fixedSize(horizontal: true, vertical: false)
                    Text("· 序号 \(log.requestSequence) · 已运行 \(runningDurationText(log))")
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer()

            Text("请求中")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accentGreen)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(theme.accentGreen.opacity(0.13))
                .clipShape(Capsule())
        }
        .padding(10)
        .cchSurface(.control)
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
                        providerMultiplier: log.costMultiplier,
                        cacheStatus: state.cacheStatus(for: log),
                        isNew: state.highlightedLogIds.contains(log.id),
                        isActive: state.panelVisible && state.selectedTab == .dashboard
                    )
                    .transition(.opacity)
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .cchSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DashboardLeaderboardPanel: View {
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme

    var accent: Color {
        switch state.leaderboardScope {
        case .user: return theme.accentOrange
        case .provider: return theme.accentPurple
        case .model: return theme.accentBlue
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
                        let scopeColor = leaderboardScopeColor(scope, theme: theme)
                        Button {
                            setScope(scope)
                        } label: {
                            Text(scope.title)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(selected ? scopeColor : theme.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(selected ? scopeColor.opacity(0.16) : theme.control)
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
        .cchSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

private func leaderboardScopeColor(_ scope: CCHLeaderboardScope) -> Color {
    leaderboardScopeColor(scope, theme: .liquidGlass)
}

private func leaderboardScopeColor(_ scope: CCHLeaderboardScope, theme: CCHThemePalette) -> Color {
    switch scope {
    case .user: return theme.accentOrange
    case .provider: return theme.accentPurple
    case .model: return theme.accentBlue
    }
}

private struct DashboardLeaderboardRow: View {
    let rank: Int
    let entry: CCHLeaderboardEntry
    let accent: Color
    let maxCost: Double
    let cacheHitRate: Double?
    let showsCache: Bool
    @Environment(\.cchTheme) private var theme

    var rankColor: Color {
        switch rank {
        case 1: return theme.accentOrange
        case 2: return theme.textSecondary
        default: return theme.accentRed
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
                            .fill(theme.control)
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
                            .foregroundStyle(cacheRateColor(cacheHitRate, theme: theme))
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
    @Environment(\.cchTheme) private var theme

    var accent: Color {
        leaderboardScopeColor(state.leaderboardScope, theme: theme)
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
                PanelLinkButton(title: "打开") {
                    state.openCCH("/zh-CN/dashboard/leaderboard")
                }
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
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("近 1 小时", systemImage: "clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(theme.control)
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
                PanelLinkButton(title: "打开") {
                    state.openCCH("/zh-CN/dashboard/logs")
                }
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
                                    providerMultiplier: log.costMultiplier,
                                    isSelected: state.selectedLog?.id == log.id,
                                    cacheStatus: state.cacheStatus(for: log),
                                    isNew: state.highlightedLogIds.contains(log.id),
                                    isActive: state.panelVisible && state.selectedTab == .logs
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
                                            .foregroundStyle(theme.textSecondary)
                                            .monospacedDigit()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .cchSurface(.panelSoft)
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

                let detailLog = state.selectedLog ?? state.logs.first
                LogDetailView(
                    log: detailLog,
                    providerMultiplier: detailLog.map(\.costMultiplier)
                )
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
                PanelLinkButton(title: "打开") {
                    state.openCCH("/zh-CN/dashboard/providers")
                }
            }

            ProviderGroupChips(state: state)

            if state.filteredProviders.isEmpty {
                EmptyStateView(text: "暂无渠道")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(state.filteredProviders) { provider in
                        ProviderRow(
                            provider: provider,
                            assignableGroups: state.assignableProviderGroups,
                            assignedGroupNames: state.assignedGroupNames(for: provider),
                            displayGroupTitles: state.displayGroupTitles(for: provider),
                            setEnabled: { value in
                                Task { await state.setProvider(provider, enabled: value) }
                            },
                            toggleGroup: { group in
                                Task { await state.toggleProviderGroupAssignment(group, for: provider) }
                            },
                            setMultiplier: { multiplier in
                                Task { await state.updateProviderMultiplier(provider, multiplier: multiplier) }
                            },
                            isMultiplierUpdating: state.isProviderMultiplierUpdating(provider),
                            probe: {
                                Task { await state.probe(provider) }
                            },
                            testModel: { model in
                                Task { await state.testProviderModel(provider, model: model) }
                            },
                            testModels: { models in
                                Task { await state.testProviderModels(provider, models: models) }
                            },
                            isModelTesting: state.isProviderModelTesting(provider),
                            modelTestResult: state.providerModelTestResult(for: provider),
                            modelTestResultsByModel: state.providerModelTestResults(for: provider),
                            modelTestProgress: state.providerModelTestProgress(for: provider),
                            customTestModels: state.customTestModels(for: provider),
                            addCustomTestModel: { model in
                                state.addCustomTestModel(model, for: provider)
                            },
                            removeCustomTestModel: { model in
                                state.removeCustomTestModel(model, for: provider)
                            },
                            resetCircuit: {
                                Task { await state.resetCircuit(provider) }
                            }
                        )
                    }
                }
                .animation(.spring(response: 0.24, dampingFraction: 0.86), value: state.filteredProviders.map { provider in
                    "\(provider.id):\(state.displayGroupTitles(for: provider).joined(separator: ","))"
                })
            }
        }
    }
}

private struct UpstreamRatesTabView: View {
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme
    @State private var editingCredential: UpstreamRateCredential?
    @State private var didInitialRefresh = false
    @State private var expandedUpstreamRateHosts: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            stats

            if state.upstreamRateSites.isEmpty {
                EmptyStateView(text: "暂无可分析的渠道")
            } else {
                siteSection(
                    title: "可同步上游",
                    subtitle: "已识别站点类型，key 匹配后可勾选同步",
                    sites: state.upstreamRateSyncableSites,
                    emptyText: "暂无可同步上游",
                    collapsible: true
                )

                if !state.upstreamRateNeedsConfigurationSites.isEmpty {
                    siteSection(
                        title: "待配置 / 登录失效",
                        subtitle: "识别到 Sub2API 或 new-api，但还没有可用登录态",
                        sites: state.upstreamRateNeedsConfigurationSites,
                        emptyText: "",
                        showConfigure: true
                    )
                }

                if !state.upstreamRateUnsupportedSites.isEmpty {
                    unsupportedSection
                }
            }
        }
        .task {
            guard !didInitialRefresh else { return }
            didInitialRefresh = true
            if state.upstreamRateSnapshots.isEmpty {
                await state.refreshUpstreamRates(silent: true)
            }
        }
        .sheet(item: $editingCredential) { credential in
            UpstreamCredentialEditor(
                credential: credential,
                onSave: { next in
                    if state.saveUpstreamCredential(next) {
                        editingCredential = nil
                        return true
                    }
                    return false
                },
                onAutoImported: { next in
                    if state.saveUpstreamCredential(next) {
                        editingCredential = nil
                        return true
                    }
                    return false
                },
                onCancel: {
                    editingCredential = nil
                }
            )
            .environment(\.cchTheme, theme)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("上游倍率")
                    .font(.system(size: 13, weight: .semibold))
                Text("按官网聚合同一上游；同步范围完全由勾选决定")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                Task { await state.refreshUpstreamRates() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(theme.accentBlue)
            .help("重新检测")

            Button {
                Task { await state.syncSelectedUpstreamRates() }
            } label: {
                Label("同步勾选项", systemImage: "checkmark.arrow.trianglehead.clockwise")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(theme.accentBlue)
            .disabled(state.upstreamRatePendingSyncCount == 0)

            Toggle("自动", isOn: $state.upstreamRateAutoSyncEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .help("按自定义频率检测并同步已勾选项")
                .onChange(of: state.upstreamRateAutoSyncEnabled) { _, _ in
                    state.startUpstreamRateAutoSyncTimer()
                }

            if state.upstreamRateAutoSyncEnabled {
                Stepper(value: $state.upstreamRateAutoSyncIntervalHours, in: 1...72, step: 1) {
                    Text("每 \(Int(state.upstreamRateAutoSyncIntervalHours)) 小时")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }
                .controlSize(.mini)
                .frame(width: 118)
                .help("自动检测/同步频率")
                .onChange(of: state.upstreamRateAutoSyncIntervalHours) { _, _ in
                    state.startUpstreamRateAutoSyncTimer()
                }
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            MiniStat(title: "官网", value: "\(state.upstreamRateSites.count)")
            MiniStat(title: "可同步", value: "\(state.upstreamRateSyncableSites.count)")
            MiniStat(title: "已勾选", value: "\(state.upstreamRateCheckedSyncCount)")
            MiniStat(
                title: "待同步",
                value: Text("\(state.upstreamRatePendingSyncCount)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.upstreamRatePendingSyncCount > 0 ? theme.accentOrange : theme.textPrimary)
            )
            Spacer(minLength: 0)
        }
    }

    private func siteSection(
        title: String,
        subtitle: String,
        sites: [UpstreamRateSite],
        emptyText: String,
        showConfigure: Bool = false,
        collapsible: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: title, subtitle: subtitle)
            if sites.isEmpty {
                EmptyStateView(text: emptyText)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sites) { site in
                        UpstreamRateSiteCard(
                            site: site,
                            state: state,
                            isCollapsible: collapsible,
                            isExpanded: !collapsible || site.pendingSyncCount > 0 || expandedUpstreamRateHosts.contains(site.id),
                            toggleExpanded: collapsible ? {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                                    if expandedUpstreamRateHosts.contains(site.id) {
                                        expandedUpstreamRateHosts.remove(site.id)
                                    } else {
                                        expandedUpstreamRateHosts.insert(site.id)
                                    }
                                }
                            } : nil,
                            configureCredential: showConfigure ? {
                                editingCredential = state.draftUpstreamCredential(for: site)
                            } : nil
                        )
                    }
                }
            }
        }
    }

    private var unsupportedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "其他官网，不参与同步", subtitle: "DeepSeek、OpenAI 官方或未知类型站点只展示，不抓倍率")
            LazyVStack(spacing: 8) {
                ForEach(state.upstreamRateUnsupportedSites) { site in
                    UpstreamRateUnsupportedCard(site: site, state: state)
                }
            }
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
    }
}

private struct UpstreamRateSiteCard: View {
    let site: UpstreamRateSite
    @ObservedObject var state: MonitorState
    var isCollapsible = false
    var isExpanded = true
    var toggleExpanded: (() -> Void)?
    var configureCredential: (() -> Void)?
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if isCollapsible {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 14, height: 18)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(site.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        UpstreamSourceBadge(type: site.sourceType)
                    }
                    Text("\(site.matchedCount)/\(site.rows.count) key 已匹配 · \(site.selectedCount) 个已勾选")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if let configureCredential {
                    Button {
                        configureCredential()
                    } label: {
                        Label("配置登录态", systemImage: "key.fill")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if site.pendingSyncCount > 0 {
                    StatusCapsule(text: "\(site.pendingSyncCount) 待同步", color: theme.accentOrange)
                } else if site.status == .available {
                    StatusCapsule(text: "已检测", color: theme.accentGreen)
                } else {
                    StatusCapsule(text: "需登录", color: theme.accentOrange)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleExpanded?()
            }

            if !isCollapsible || isExpanded {
                ForEach(site.rows) { row in
                    UpstreamRateProviderSyncRow(row: row, state: state)
                }
            }
        }
        .padding(10)
        .cchSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

private struct UpstreamRateProviderSyncRow: View {
    let row: UpstreamRateProviderRow
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme

    private var statusColor: Color {
        switch row.matchStatus {
        case .matched: return row.hasRateChange ? theme.accentOrange : theme.accentGreen
        case .unmatched: return theme.textTertiary
        case .unsupported: return theme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(color: statusColor)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(row.providerName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    UpstreamHostBadge(host: row.host)
                    if let group = row.upstreamGroupName {
                        UpstreamGroupBadge(group: group)
                    }
                }
                HStack(spacing: 6) {
                    Text("CCH")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                    MultiplierBadge(value: row.currentRate, compact: true)
                    if let upstreamRate = row.upstreamRate {
                        Text(row.hasRateChange ? "→" : "=")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                        Text("上游")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                        MultiplierBadge(value: upstreamRate, compact: true)
                    } else {
                        Text(row.matchStatus == .matched ? "未勾选，不参与批量/自动同步" : "暂未匹配上游 key")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 6)
            if state.isUpstreamRateProviderUpdating(row.providerId) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 24, height: 20)
            } else {
                Button {
                    Task { await state.syncUpstreamRate(row) }
                } label: {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(row.matchStatus == .matched ? theme.accentBlue : theme.textTertiary)
                .disabled(row.matchStatus != .matched || row.upstreamRate == nil)
                .help("手动同步此 key")
            }

            Button {
                state.toggleUpstreamRateSyncSelection(row)
            } label: {
                Image(systemName: row.isSelectedForSync ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18, height: 20)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(row.isSelectedForSync ? theme.accentBlue : theme.textTertiary)
            .disabled(row.matchStatus != .matched)
            .help(row.isSelectedForSync ? "取消批量/自动同步" : "参与批量/自动同步")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .cchSurface(.row)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct UpstreamRateUnsupportedCard: View {
    let site: UpstreamRateSite
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(color: theme.textTertiary)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(site.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                    UpstreamHostBadge(host: site.host)
                    StatusCapsule(text: "仅展示", color: theme.textTertiary)
                }
                Text(site.rows.map(\.providerName).joined(separator: "、"))
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                Button("new-api") {
                    state.setUpstreamRateSourceType(host: site.host, sourceType: .newAPI)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                Button("Sub2API") {
                    state.setUpstreamRateSourceType(host: site.host, sourceType: .sub2API)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .cchSurface(.panelSoft)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

private struct UpstreamHostBadge: View {
    let host: String
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "globe")
                .font(.system(size: 7.5, weight: .bold))
            Text(host)
                .lineLimit(1)
        }
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(theme.accentBlue)
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(theme.accentBlue.opacity(0.11))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.accentBlue.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct UpstreamGroupBadge: View {
    let group: String
    @Environment(\.cchTheme) private var theme

    var body: some View {
        Text(group)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(theme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(theme.textSecondary.opacity(0.10))
            .overlay(Capsule().stroke(theme.textSecondary.opacity(0.25), lineWidth: 1))
            .clipShape(Capsule())
    }
}

private struct UpstreamSourceBadge: View {
    let type: UpstreamRateSourceType
    @Environment(\.cchTheme) private var theme

    private var color: Color {
        switch type {
        case .newAPI: return theme.accentBlue
        case .sub2API: return theme.accentOrange
        case .unknown: return theme.textTertiary
        }
    }

    var body: some View {
        Text(type.title)
            .font(.system(size: 8.5, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.24), lineWidth: 1))
    }
}

private struct UpstreamCredentialEditor: View {
    @State private var credential: UpstreamRateCredential
    @StateObject private var chromeImporter = UpstreamChromeAuthImporter()
    @State private var authMessage: String?
    @State private var authMessageIsWarning = false
    @State private var showManualFields = false
    let onSave: (UpstreamRateCredential) -> Bool
    let onAutoImported: (UpstreamRateCredential) -> Bool
    let onCancel: () -> Void
    @Environment(\.cchTheme) private var theme

    init(
        credential: UpstreamRateCredential,
        onSave: @escaping (UpstreamRateCredential) -> Bool,
        onAutoImported: @escaping (UpstreamRateCredential) -> Bool,
        onCancel: @escaping () -> Void
    ) {
        _credential = State(initialValue: credential)
        self.onSave = onSave
        self.onAutoImported = onAutoImported
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(theme.accentBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("配置上游登录态")
                        .font(.system(size: 14, weight: .semibold))
                    Text(credential.host)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }

            Picker("类型", selection: $credential.sourceType) {
                Text("new-api").tag(UpstreamRateSourceType.newAPI)
                Text("Sub2API").tag(UpstreamRateSourceType.sub2API)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Base URL")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                TextField("https://example.com", text: $credential.baseURL)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 8) {
                Button {
                    Task { await captureChromeLoginState() }
                } label: {
                    if chromeImporter.isImporting {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 18, height: 16)
                        Text(chromeImporter.step.title)
                            .font(.system(size: 11, weight: .semibold))
                    } else {
                        Label("一键获取登录态", systemImage: "globe.badge.chevron.backward")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(theme.accentBlue)
                .disabled(chromeImporter.isImporting)

                if let authMessage {
                    Text(authMessage)
                        .font(.caption2)
                        .foregroundStyle(authMessageIsWarning ? theme.accentOrange : theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            DisclosureGroup("高级手动填写", isExpanded: $showManualFields) {
                if credential.sourceType == .newAPI {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User ID")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        TextField("localStorage user.id", text: $credential.newAPIUserId)
                            .textFieldStyle(.roundedBorder)
                        Text("Access Token")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        SecureField("localStorage access_token", text: $credential.newAPIAccessToken)
                            .textFieldStyle(.roundedBorder)
                        if !credential.newAPICookieHeader.isEmpty {
                            Label("已捕获浏览器 Cookie", systemImage: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(theme.accentBlue)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auth Token")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        SecureField("auth_token", text: $credential.sub2AuthToken)
                            .textFieldStyle(.roundedBorder)
                        Text("Refresh Token")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        SecureField("refresh_token", text: $credential.sub2RefreshToken)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.top, 8)
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.textSecondary)

            HStack(spacing: 8) {
                Spacer()
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("保存并检测") {
                    _ = onSave(normalizedCredential)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentBlue)
                .keyboardShortcut(.defaultAction)
                .disabled(normalizedCredential.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 430)
        .background(theme.settingsBackgroundBase)
        .onDisappear {
            chromeImporter.closeChrome()
        }
    }

    private func captureChromeLoginState() async {
        do {
            let result = try await chromeImporter.captureLogin(for: normalizedCredential)
            credential = result.credential
            authMessage = "获取成功"
            authMessageIsWarning = false
            _ = onAutoImported(result.credential)
        } catch {
            authMessage = error.localizedDescription
            authMessageIsWarning = true
        }
    }

    private var normalizedCredential: UpstreamRateCredential {
        var next = credential
        next.baseURL = next.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        next.host = normalizedUpstreamHost(next.baseURL) ?? credential.host
        return next
    }
}

private struct ProviderGroupChips: View {
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Text("分组")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(state.providerGroups, id: \.self) { group in
                        Button {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                state.toggleProviderGroup(group)
                            }
                        } label: {
                            let selected = state.isProviderGroupSelected(group)
                            let color = group == "全部" ? theme.accentBlue : providerGroupColor(group, theme: theme)
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
    @Environment(\.cchTheme) private var theme

    init(title: String, value: String, detail: String, color: Color, icon: String) {
        self.title = title
        self.value = AnyView(
            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.24), value: value)
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
                    .foregroundStyle(theme.textSecondary)
            }
            value
            Text(detail)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(12)
        .cchSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

private struct MiniStat: View {
    let title: String
    let value: AnyView
    @Environment(\.cchTheme) private var theme

    init(title: String, value: String) {
        self.title = title
        self.value = AnyView(
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.22), value: value)
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
                .foregroundStyle(theme.textSecondary)
            value
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .cchSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct UsageMetricColumn: View {
    let top: Int
    let bottom: Int
    let topColor: Color
    let bottomColor: Color
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(top > 0 ? compactNumber(top) : "-")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(top > 0 ? topColor : theme.textTertiary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(bottom > 0 ? compactNumber(bottom) : "-")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(bottom > 0 ? bottomColor : theme.textTertiary)
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
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(theme.textSecondary)
            Text(top > 0 ? compactNumber(top) : "-")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(top > 0 ? topColor : theme.textTertiary)
                .monospacedDigit()
            Text(bottom > 0 ? compactNumber(bottom) : "-")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(bottom > 0 ? bottomColor : theme.textTertiary.opacity(0.82))
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
    @Environment(\.cchTheme) private var theme

    var color: Color {
        switch multiplierLevel(value) {
        case 0, 1: return theme.accentGreen
        case 2: return theme.accentOrange
        default: return theme.accentRed
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
    var compact = false
    @Environment(\.cchTheme) private var theme

    var body: some View {
        Text("FAST")
            .font(.system(size: compact ? 7.8 : 8.5, weight: .bold, design: .rounded))
            .foregroundStyle(theme.accentOrange)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, compact ? 4 : 5)
            .padding(.vertical, 1)
            .background(theme.accentOrange.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.accentOrange.opacity(0.24), lineWidth: 0.7))
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

private struct ProviderAssignmentChip: View {
    let title: String
    let selected: Bool
    let color: Color
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 3) {
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .black))
                    .transition(.scale.combined(with: .opacity))
            }
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 9.5, weight: selected ? .bold : .semibold))
        .foregroundStyle(selected ? color : theme.textSecondary)
        .padding(.horizontal, selected ? 7 : 6)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(selected ? color.opacity(0.18) : theme.panelSoft.opacity(0.72))
        )
        .overlay(
            Capsule()
                .stroke(selected ? color.opacity(0.62) : theme.border.opacity(0.55), lineWidth: 0.8)
        )
    }
}

private struct HoverLink: View {
    let title: String
    let icon: String
    let url: URL
    @State private var isHovering = false
    @Environment(\.cchTheme) private var theme

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
            .background(isHovering ? theme.accentBlue.opacity(0.16) : Color.clear)
            .clipShape(Capsule())
            .offset(y: isHovering ? -0.5 : 0)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? theme.accentBlue : theme.accentBlue.opacity(0.88))
        .animation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.16), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
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
                PanelLinkButton(title: actionTitle, action: action)
            }
        }
    }
}

private struct PanelLinkButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.cchTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .lineLimit(1)
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 8.5, weight: .black))
                    .offset(x: isHovering ? 1 : 0, y: isHovering ? -1 : 0)
            }
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(isHovering ? theme.backgroundBottom : theme.accentBlue)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(isHovering ? theme.accentBlue : theme.accentBlue.opacity(0.13))
            )
            .overlay(
                Capsule()
                    .stroke(theme.accentBlue.opacity(isHovering ? 0.85 : 0.36), lineWidth: 1)
            )
            .shadow(color: theme.accentBlue.opacity(isHovering ? 0.24 : 0), radius: 5, y: 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("打开对应页面")
        .animation(.easeInOut(duration: 0.14), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct ActiveSessionRow: View {
    let session: CCHActiveSession
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(color: session.concurrentCount > 0 ? theme.accentGreen : theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    ModelBrandIcon(model: session.model.isEmpty ? session.apiType : session.model, provider: session.providerName, size: 13)
                    Text(session.model.isEmpty ? session.apiType : session.model)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                Text("\(session.userName) · \(session.keyName) · \(session.providerName)")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(session.requestCount)x")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
            MoneyValue(value: session.costUsd, majorSize: 12, minorSize: 7, weight: .semibold)
                .frame(width: 62, alignment: .trailing)
        }
        .padding(9)
        .cchSurface(.row)
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
    @Environment(\.cchTheme) private var theme

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
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if canExpand {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(theme.textSecondary)
                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            }
                        }
                        Text(entry.subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Text("\(compactNumber(entry.requests)) 次")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                        .frame(width: 64, alignment: .trailing)
                    Text(compactNumber(entry.tokens))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                    if showsCache, let cacheHitRate {
                        Text(formatPercent(cacheHitRate))
                            .font(.caption)
                            .foregroundStyle(cacheRateColor(cacheHitRate, theme: theme))
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
                            theme.panelSoft
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
        .cchSurface(.row)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.borderSubtle, lineWidth: 1))
        .animation(.easeInOut(duration: 0.16), value: isExpanded)
    }
}

private struct LeaderboardModelStatRow: View {
    let stat: CCHLeaderboardModelStat
    @Environment(\.cchTheme) private var theme

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
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
            Text(compactNumber(stat.tokens))
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)
            if let cacheHitRate = stat.cacheHitRate {
                Text(formatPercent(cacheHitRate))
                    .font(.caption2)
                    .foregroundStyle(cacheRateColor(cacheHitRate, theme: theme))
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
                    theme.row,
                    theme.panelSoft
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
    let providerMultiplier: Double
    let isSelected: Bool
    let cacheStatus: CCHCacheStatusContext
    let isNew: Bool
    let isActive: Bool
    @Environment(\.cchTheme) private var theme

    var statusColor: Color {
        guard let code = log.statusCode else { return theme.textTertiary }
        if (200..<300).contains(code) { return theme.accentGreen }
        if code >= 500 { return theme.accentRed }
        return theme.accentOrange
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
            LogStatusIndicator(color: statusColor, isRunning: log.statusCode == nil, isActive: isActive)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    ModelBrandIcon(model: model, provider: log.providerName, size: 13)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(model)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(0)
                    if log.isFastTier {
                        FastTierBadge()
                    }
                    MultiplierBadge(value: providerMultiplier, compact: true)
                        .fixedSize(horizontal: true, vertical: false)
                    StatusCapsule(text: log.statusCode.map(String.init) ?? "请求中", color: statusColor)
                        .fixedSize(horizontal: true, vertical: false)
                }
                HStack(spacing: 4) {
                    Text(log.userName.isEmpty ? "-" : log.userName)
                        .cchUserAccent()
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
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            Spacer()
            UsageMetricColumn(
                top: log.outputTokens,
                bottom: log.inputTokens,
                topColor: theme.textPrimary,
                bottomColor: theme.textSecondary
            )
            .frame(width: 48, alignment: .trailing)
            UsageMetricColumn(
                top: log.cacheCreationTokens,
                bottom: log.cacheReadTokens,
                topColor: cacheCreationDisplayColor(cacheStatus, theme: theme),
                bottomColor: cacheReadDisplayColor(cacheStatus, theme: theme)
            )
            .frame(width: 56, alignment: .trailing)
            MoneyValue(value: log.costUsd, majorSize: 11.5, minorSize: 6.8, weight: .semibold)
                .frame(width: 62, alignment: .trailing)
            VStack(alignment: .trailing, spacing: 1) {
                Text(formatMillisecondsAsSeconds(log.durationMs))
                    .font(.caption)
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                Text("TTFB \(formatMillisecondsAsSeconds(log.ttfbMs))")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                Text(formatTokensPerSecond(throughput))
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }
            .frame(width: 76, alignment: .trailing)
        }
        .padding(8)
        .background(isSelected ? theme.rowSelected : theme.control)
        .overlay(alignment: .leading) {
            NewLogEdgeFlash(active: isNew && isActive)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .cchMicroReveal(active: isNew && isActive)
    }
}

private struct CompactLogRow: View {
    let log: CCHLogEntry
    let providerMultiplier: Double
    let cacheStatus: CCHCacheStatusContext
    let isNew: Bool
    let isActive: Bool
    @Environment(\.cchTheme) private var theme

    var statusColor: Color {
        guard let code = log.statusCode else { return theme.accentGreen }
        if (200..<300).contains(code) { return theme.accentGreen }
        if code >= 500 { return theme.accentRed }
        return theme.accentOrange
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
            LogStatusIndicator(color: statusColor, isRunning: log.statusCode == nil, isActive: isActive)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(log.providerName.isEmpty ? "渠道" : log.providerName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textAdaptiveWidth(log.providerName.isEmpty ? "渠道" : log.providerName, limit: 128, compactThreshold: 15)
                    MultiplierBadge(value: providerMultiplier, compact: true)
                    if log.isFastTier {
                        FastTierBadge(compact: true)
                    }
                }
                HStack(spacing: 4) {
                    Text(log.userName.isEmpty ? "-" : log.userName)
                        .cchUserAccent()
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
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            Spacer()
            CompactUsageMetric(
                title: "TOK",
                top: log.outputTokens,
                bottom: log.inputTokens,
                topColor: theme.textPrimary,
                bottomColor: theme.textSecondary
            )
            CompactUsageMetric(
                title: "CACHE",
                top: log.cacheCreationTokens,
                bottom: log.cacheReadTokens,
                topColor: cacheCreationDisplayColor(cacheStatus, theme: theme),
                bottomColor: cacheReadDisplayColor(cacheStatus, theme: theme)
            )
            StatusCapsule(text: statusText, color: statusColor)
                .frame(width: 50, alignment: .trailing)
            VStack(alignment: .trailing, spacing: 1) {
                Text(formatMillisecondsAsSeconds(log.durationMs))
                    .foregroundStyle(theme.textPrimary)
                Text("TTFB \(formatMillisecondsAsSeconds(log.ttfbMs))")
                Text(formatTokensPerSecond(throughput))
            }
            .font(.caption2)
            .foregroundStyle(theme.textSecondary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.92)
            .frame(width: 76, alignment: .trailing)
        }
        .padding(8)
        .cchSurface(.control)
        .overlay(alignment: .leading) {
            NewLogEdgeFlash(active: isNew && isActive)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .cchMicroReveal(active: isNew && isActive)
    }
}

private struct CompactProviderRow: View {
    let provider: CCHProvider
    @Environment(\.cchTheme) private var theme

    var healthColor: Color {
        if provider.health.circuitState.lowercased() == "open" { return theme.accentRed }
        if provider.health.failureCount > 0 { return theme.accentOrange }
        return provider.isEnabled ? theme.accentGreen : theme.textTertiary
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
                Text(provider.isEnabled ? "\(providerCircuitStateTitle(provider.health.circuitState)) · 失败 \(provider.health.failureCount)" : "已停用")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            MultiplierBadge(value: provider.costMultiplier, compact: true)
        }
        .padding(8)
        .cchSurface(.control)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LogDetailView: View {
    let log: CCHLogEntry?
    let providerMultiplier: Double?
    @Environment(\.cchTheme) private var theme

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
                DetailLine("倍率", value: formatMultiplier(providerMultiplier ?? logProviderMultiplier(log)))
                DetailLine("Tokens", value: "\(compactNumber(log.totalTokens))  in \(compactNumber(log.inputTokens)) / out \(compactNumber(log.outputTokens))")
                DetailLine("缓存", value: "\(compactNumber(log.cacheCreationTokens)) 写 / \(compactNumber(log.cacheReadTokens)) 读")
                DetailLine("性能", value: "\(formatMillisecondsAsSeconds(log.durationMs)) · TTFB \(formatMillisecondsAsSeconds(log.ttfbMs)) · \(formatTokensPerSecond(throughput(log)))")
                if !log.errorMessage.isEmpty {
                    Text(log.errorMessage)
                        .font(.caption)
                        .foregroundStyle(theme.accentRed)
                        .lineLimit(4)
                }
                Divider().opacity(0.35)
                HStack {
                    Text("供应商决策链")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("\(attemptCount(log.providerChain))次")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .cchSurface(.row)
                        .clipShape(Capsule())
                }
                if log.providerChain.isEmpty {
                    Text("-")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
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
        .cchSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ProviderChainRow: View {
    let item: CCHProviderChainItem
    @Environment(\.cchTheme) private var theme

    var statusColor: Color {
        guard let code = item.statusCode else {
            return item.reason.contains("error") || item.reason.contains("fail") ? theme.accentRed : theme.textTertiary
        }
        if (200..<300).contains(code) { return theme.accentGreen }
        if code == 429 || code >= 500 { return theme.accentRed }
        return theme.accentOrange
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
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                if !item.errorMessage.isEmpty {
                    Text(item.errorMessage)
                        .font(.caption2)
                        .foregroundStyle(theme.accentRed)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let attempt = item.attemptNumber {
                Text("#\(attempt)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(8)
        .cchSurface(.control)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProviderRow: View {
    let provider: CCHProvider
    let assignableGroups: [CCHProviderGroup]
    let assignedGroupNames: Set<String>
    let displayGroupTitles: [String]
    let setEnabled: (Bool) -> Void
    let toggleGroup: (CCHProviderGroup) -> Void
    let setMultiplier: (Double) -> Void
    let isMultiplierUpdating: Bool
    let probe: () -> Void
    let testModel: (String) -> Void
    let testModels: ([String]) -> Void
    let isModelTesting: Bool
    let modelTestResult: CCHProviderModelTestResult?
    let modelTestResultsByModel: [String: CCHProviderModelTestResult]
    let modelTestProgress: CCHProviderModelTestProgress?
    let customTestModels: [String]
    let addCustomTestModel: (String) -> Void
    let removeCustomTestModel: (String) -> Void
    let resetCircuit: () -> Void
    @State private var modelTestInput = ""
    @State private var multiplierInput = ""
    @State private var renderedEditor: ProviderEditor?
    @State private var editorRevealHeight: CGFloat = 0
    @Environment(\.cchTheme) private var theme

    private enum ProviderEditor: Equatable {
        case multiplier
        case modelTest
    }

    var healthColor: Color {
        if provider.health.circuitState.lowercased() == "open" { return theme.accentRed }
        if provider.health.failureCount > 0 { return theme.accentOrange }
        return provider.isEnabled ? theme.accentGreen : theme.textTertiary
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
                            ForEach(displayGroupTitles.prefix(2), id: \.self) { group in
                                ProviderTag(group, color: providerGroupColor(group, theme: theme))
                                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.22, dampingFraction: 0.84), value: displayGroupTitles)
                        HStack(spacing: 6) {
                            ProviderTag("优先级 \(provider.priority)", color: theme.textSecondary)
                            ProviderTag("权重 \(provider.weight)", color: theme.textSecondary)
                            Button {
                                multiplierInput = multiplierInputString(provider.costMultiplier)
                                toggleEditor(.multiplier)
                            } label: {
                                Group {
                                    if isMultiplierUpdating {
                                        ProgressView()
                                            .scaleEffect(0.45)
                                            .frame(width: 28, height: 16)
                                    } else {
                                        MultiplierBadge(value: provider.costMultiplier, compact: true)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isMultiplierUpdating)
                            .help("编辑倍率")
                        }
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(provider.todayCalls) 次")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        MoneyValue(value: provider.todayCost, majorSize: 10.5, minorSize: 6.2, weight: .semibold, color: theme.textSecondary)
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
                    Text(providerCircuitStateTitle(provider.health.circuitState))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(healthColor)
                    if let websiteURL {
                        HoverLink(title: "官网", icon: "globe", url: websiteURL)
                    }
                    Text("失败 \(provider.health.failureCount)")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Text(provider.limitText)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        modelTestInput = modelTestInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? provider.testModel
                            : modelTestInput
                        toggleEditor(.modelTest)
                    } label: {
                        Group {
                            if isModelTesting {
                                ProgressView()
                                    .scaleEffect(0.45)
                            } else {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentOrange)
                    .disabled(isModelTesting)
                    .help("供应商模型测试")
                    Button {
                        probe()
                    } label: {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentOrange)
                    .help("测速")
                    if provider.health.circuitState.lowercased() == "open" {
                        Button("重置") {
                            resetCircuit()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if let renderedEditor {
                    ProviderEditorReveal(
                        revealHeight: editorRevealHeight,
                        contentHeight: editorHeight(renderedEditor)
                    ) {
                        ProviderInlineEditorContainer {
                            switch renderedEditor {
                            case .multiplier:
                                ProviderMultiplierPopover(
                                    provider: provider,
                                    multiplier: $multiplierInput,
                                    isUpdating: isMultiplierUpdating
                                ) { value in
                                    closeEditor()
                                    setMultiplier(value)
                                }
                            case .modelTest:
                                ProviderModelTestPopover(
                                    provider: provider,
                                    model: $modelTestInput,
                                    isTesting: isModelTesting,
                                    result: modelTestResult,
                                    resultsByModel: modelTestResultsByModel,
                                    progress: modelTestProgress,
                                    customModels: customTestModels,
                                    addModel: addCustomTestModel,
                                    removeModel: removeCustomTestModel,
                                    runSingle: testModel,
                                    runBatch: testModels
                                )
                            }
                        }
                    }
                }
                if !assignableGroups.isEmpty {
                    HStack(spacing: 7) {
                        Text("分组")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(assignableGroups) { group in
                                    let selected = assignedGroupNames.contains(group.name)
                                    Button {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.82)) {
                                            toggleGroup(group)
                                        }
                                    } label: {
                                        ProviderAssignmentChip(
                                            title: group.name,
                                            selected: selected,
                                            color: providerGroupColor(group.name, theme: theme)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .help(selected ? "移出 \(group.name)" : "加入 \(group.name)")
                                }
                            }
                        }
                        .frame(height: 21)
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.86), value: assignedGroupNames)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .cchSurface(.row)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onChange(of: customTestModels) {
            guard renderedEditor == .modelTest else { return }
            withAnimation(editorSwitchAnimation) {
                editorRevealHeight = editorHeight(.modelTest)
            }
        }
    }

    private func toggleEditor(_ editor: ProviderEditor) {
        if renderedEditor == editor, editorRevealHeight > 0 {
            closeEditor()
            return
        }

        let targetHeight = editorHeight(editor)
        if renderedEditor == nil {
            renderedEditor = editor
            editorRevealHeight = 0
            DispatchQueue.main.async {
                withAnimation(editorOpenAnimation) {
                    editorRevealHeight = targetHeight
                }
            }
        } else {
            renderedEditor = editor
            withAnimation(editorSwitchAnimation) {
                editorRevealHeight = targetHeight
            }
        }
    }

    private func closeEditor() {
        let closingEditor = renderedEditor
        withAnimation(editorCloseAnimation) {
            editorRevealHeight = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if renderedEditor == closingEditor, editorRevealHeight == 0 {
                renderedEditor = nil
            }
        }
    }

    private func editorHeight(_ editor: ProviderEditor) -> CGFloat {
        switch editor {
        case .multiplier:
            return 70
        case .modelTest:
            return customTestModels.isEmpty ? 76 : 112
        }
    }

    private var editorOpenAnimation: Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.24)
    }

    private var editorSwitchAnimation: Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.2)
    }

    private var editorCloseAnimation: Animation {
        .easeInOut(duration: 0.2)
    }
}

private struct ProviderEditorReveal<Content: View>: View {
    let revealHeight: CGFloat
    let contentHeight: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(height: contentHeight, alignment: .top)
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: revealHeight, alignment: .top)
        .clipped()
    }
}

private struct ProviderInlineEditorContainer<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.cchTheme) private var theme

    var body: some View {
        content
            .cchSurface(.control)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProviderMultiplierPopover: View {
    let provider: CCHProvider
    @Binding var multiplier: String
    let isUpdating: Bool
    let apply: (Double) -> Void
    @Environment(\.cchTheme) private var theme

    private let quickValues: [Double] = [0, 0.05, 0.1, 0.2, 0.5, 1, 2]

    private var normalizedMultiplier: Double? {
        parseMultiplierInput(multiplier)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(quickValues, id: \.self) { value in
                        let selected = normalizedMultiplier.map { abs($0 - value) < 0.0001 } ?? false
                        Button {
                            multiplier = multiplierInputString(value)
                        } label: {
                            Text(formatMultiplier(value))
                                .font(.system(size: 10.5, weight: selected ? .bold : .semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(selected ? theme.accentGreen.opacity(0.24) : theme.textTertiary.opacity(0.12))
                                )
                                .foregroundStyle(selected ? theme.accentGreen : theme.textSecondary)
                                .overlay(
                                    Capsule()
                                        .stroke(selected ? theme.accentGreen.opacity(0.75) : theme.textTertiary.opacity(0.24), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 26)

            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accentGreen)
                    .frame(width: 18)
                TextField("倍率", text: $multiplier)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .medium))
                    .onSubmit {
                        if let normalizedMultiplier, !isUpdating {
                            apply(normalizedMultiplier)
                        }
                    }
                Spacer()
                Button {
                    if let normalizedMultiplier {
                        apply(normalizedMultiplier)
                    }
                } label: {
                    if isUpdating {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 18, height: 18)
                    } else {
                        Label("保存", systemImage: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentGreen)
                .disabled(isUpdating || normalizedMultiplier == nil)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if multiplier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                multiplier = multiplierInputString(provider.costMultiplier)
            }
        }
    }
}

private struct ProviderModelTestPopover: View {
    let provider: CCHProvider
    @Binding var model: String
    let isTesting: Bool
    let result: CCHProviderModelTestResult?
    let resultsByModel: [String: CCHProviderModelTestResult]
    let progress: CCHProviderModelTestProgress?
    let customModels: [String]
    let addModel: (String) -> Void
    let removeModel: (String) -> Void
    let runSingle: (String) -> Void
    let runBatch: ([String]) -> Void
    @Environment(\.cchTheme) private var theme

    private var normalizedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var testQueue: [String] {
        let models = normalizedProviderTestModels(customModels)
        return models.isEmpty ? normalizedProviderTestModels([normalizedModel]) : models
    }

    private var canAddModel: Bool {
        !normalizedModel.isEmpty
            && customModels.count < 8
            && !customModels.contains { $0.caseInsensitiveCompare(normalizedModel) == .orderedSame }
    }

    private var canRun: Bool {
        !testQueue.isEmpty
    }

    private var resultColor: Color {
        guard let result else { return theme.textSecondary }
        let status = result.status.lowercased()
        if result.success || status == "green" { return theme.accentGreen }
        if status == "yellow" { return theme.accentOrange }
        return theme.accentRed
    }

    private var resultTitle: String {
        guard let result else { return "等待测试" }
        let status = result.status.lowercased()
        if result.success || status == "green" { return "可用" }
        if status == "yellow" { return "波动" }
        return "失败"
    }

    private var resultDetail: String {
        guard let result else { return "输入模型名称后开始测试" }
        let latency = result.latencyMs.map(formatProbeLatency) ?? "-"
        let displayModel = result.model.isEmpty ? normalizedModel : result.model
        let detail = result.errorMessage.isEmpty ? result.message : result.errorMessage
        if result.success || result.status.lowercased() == "green" || result.status.lowercased() == "yellow" {
            return "\(latency) · \(displayModel)"
        }
        return detail.isEmpty ? displayModel : detail
    }

    private var statusId: String {
        if isTesting { return "testing" }
        guard let result else { return "idle" }
        return "\(result.status)-\(result.success)-\(result.model)-\(result.errorMessage)-\(result.latencyMs ?? -1)"
    }

    private var progressValue: Double {
        guard let progress, progress.total > 0 else { return 0 }
        return min(1, max(0, Double(progress.completed) / Double(progress.total)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accentOrange)
                    .frame(width: 18)
                TextField("模型", text: $model)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .medium))
                    .onSubmit {
                        if !normalizedModel.isEmpty, !isTesting {
                            if customModels.isEmpty {
                                runSingle(normalizedModel)
                            } else {
                                addModel(normalizedModel)
                            }
                        }
                    }
                Button {
                    addModel(normalizedModel)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10.5, weight: .bold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canAddModel ? theme.accentGreen : theme.textTertiary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(canAddModel ? theme.accentGreen.opacity(0.18) : theme.textTertiary.opacity(0.1))
                )
                .disabled(!canAddModel || isTesting)
                .help("加入此渠道的测试模型")
                Spacer()
                Button {
                    if customModels.isEmpty {
                        runSingle(normalizedModel)
                    } else {
                        runBatch(testQueue)
                    }
                } label: {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10.5, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(!canRun || isTesting ? theme.accentOrange.opacity(0.36) : theme.accentOrange)
                )
                .disabled(isTesting || !canRun)
            }
            .frame(height: 30)

            if !customModels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(customModels, id: \.self) { testModel in
                            ProviderModelTestChip(
                                model: testModel,
                                result: resultsByModel[testModel],
                                isCurrent: isTesting && (progress?.currentModel.caseInsensitiveCompare(testModel) == .orderedSame)
                            ) {
                                removeModel(testModel)
                            }
                        }
                    }
                }
                .frame(height: 24)
            }

            ProviderModelTestStatusView(
                id: statusId,
                title: progress.map { "\($0.completed)/\($0.total)" } ?? resultTitle,
                detail: progress.map { "正在测试 \($0.currentModel)" } ?? resultDetail,
                color: result == nil ? theme.textSecondary : resultColor,
                isTesting: isTesting,
                progress: progressValue
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if normalizedModel.isEmpty {
                model = provider.testModel
            }
        }
    }
}

private struct ProviderModelTestStatusView: View {
    let id: String
    let title: String
    let detail: String
    let color: Color
    let isTesting: Bool
    let progress: Double
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isTesting ? theme.accentOrange : color)
                    .frame(width: 6, height: 6)
                Text(isTesting ? title : title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isTesting ? theme.accentOrange : color)
                Text("·")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            if isTesting {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.textTertiary.opacity(0.16))
                        Capsule()
                            .fill(theme.accentOrange.opacity(0.78))
                            .frame(width: max(8, proxy.size.width * progress))
                        CCHProgressShimmer(color: theme.accentOrange)
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
    }
}

private struct ProviderModelTestChip: View {
    let model: String
    let result: CCHProviderModelTestResult?
    let isCurrent: Bool
    let remove: () -> Void
    @Environment(\.cchTheme) private var theme

    private var color: Color {
        if isCurrent { return theme.accentOrange }
        guard let result else { return theme.textTertiary }
        let status = result.status.lowercased()
        if result.success || status == "green" { return theme.accentGreen }
        if status == "yellow" { return theme.accentOrange }
        return theme.accentRed
    }

    private var detail: String? {
        guard let result else { return nil }
        if result.success || result.status.lowercased() == "green" || result.status.lowercased() == "yellow" {
            return result.latencyMs.map(formatProbeLatency)
        }
        return "失败"
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(model)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(theme.textPrimary)
            if let detail {
                Text(detail)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
            Button {
                remove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(isCurrent ? 0.18 : 0.12))
        .overlay(Capsule().stroke(color.opacity(isCurrent ? 0.42 : 0.22), lineWidth: 1))
        .clipShape(Capsule())
    }
}

private struct DetailLine: View {
    let title: String
    let value: String
    @Environment(\.cchTheme) private var theme

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.textSecondary)
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

private struct RunningSessionIndicator: View {
    @State private var pulse = false
    @Environment(\.cchTheme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.accentGreen.opacity(pulse ? 0 : 0.52), lineWidth: 1.6)
                .frame(width: 20, height: 20)
                .scaleEffect(pulse ? 1.24 : 1)
            CCHTriangleMark()
                .fill(theme.accentGreen)
                .frame(width: 8.8, height: 8.8)
        }
        .frame(width: 26, height: 26)
        .onAppear {
            pulse = false
            withAnimation(.easeOut(duration: 1.15).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .onDisappear {
            pulse = false
        }
    }
}

private struct LogStatusIndicator: View {
    let color: Color
    let isRunning: Bool
    let isActive: Bool
    @State private var pulse = false
    @Environment(\.cchTheme) private var theme

    init(color: Color, isRunning: Bool, isActive: Bool = true) {
        self.color = color
        self.isRunning = isRunning
        self.isActive = isActive
    }

    var runningColor: Color {
        theme.accentBlue
    }

    private var shouldPulse: Bool {
        isRunning && isActive
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
            updatePulse()
        }
        .onChange(of: shouldPulse) { _, _ in
            updatePulse()
        }
        .onDisappear {
            pulse = false
        }
    }

    private func updatePulse() {
        guard shouldPulse else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(.easeOut(duration: 1.05).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

private struct EmptyStateView: View {
    let text: String
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .padding(.vertical, 18)
            Spacer()
        }
        .cchSurface(.row)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func multiplierInputString(_ value: Double) -> String {
    var output = String(format: "%.4f", value)
    while output.contains("."), output.last == "0" {
        output.removeLast()
    }
    if output.last == "." {
        output.removeLast()
    }
    return output.isEmpty ? "0" : output
}

private func parseMultiplierInput(_ value: String) -> Double? {
    let normalized = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .replacingOccurrences(of: "×", with: "")
        .replacingOccurrences(of: "x", with: "")
        .replacingOccurrences(of: "，", with: ".")
    guard let multiplier = Double(normalized), multiplier >= 0 else {
        return nil
    }
    return multiplier
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

private func cacheRateColor(_ rate: Double?, theme: CCHThemePalette) -> Color {
    guard let rate else { return theme.textTertiary }
    switch rate {
    case let value where value >= 0.85:
        return theme.accentGreen
    case let value where value >= 0.6:
        return theme.accentOrange
    default:
        return theme.accentRed
    }
}

private func providerGroupColor(_ group: String, theme: CCHThemePalette) -> Color {
    let normalized = group.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.isEmpty || normalized == "全部" || normalized == "默认" || normalized == "default" {
        return theme.textSecondary
    }

    let palette = [
        theme.accentBlue,
        theme.accentGreen,
        theme.accentOrange,
        theme.accentPurple,
        theme.accentMint
    ]
    let hash = normalized.unicodeScalars.reduce(5381) { partial, scalar in
        ((partial << 5) &+ partial) &+ Int(scalar.value)
    }
    return palette[abs(hash) % palette.count]
}

private func providerCircuitStateTitle(_ value: String) -> String {
    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "closed":
        return "正常"
    case "open":
        return "熔断"
    case "half_open", "half-open", "halfopen":
        return "恢复中"
    case let state where state.isEmpty:
        return "未知"
    default:
        return value.uppercased()
    }
}

private func cacheCreationDisplayColor(_ status: CCHCacheStatusContext, theme: CCHThemePalette) -> Color {
    switch status.state {
    case .rebuilding:
        return theme.accentRed
    case .normal:
        return status.createdTokens > 0 ? theme.accentGreen : theme.textTertiary
    }
}

private func cacheReadDisplayColor(_ status: CCHCacheStatusContext, theme: CCHThemePalette) -> Color {
    switch status.state {
    case .rebuilding:
        return theme.accentRed
    case .normal:
        return status.readTokens > 0 ? theme.accentGreen : theme.textTertiary
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
