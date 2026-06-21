import Combine
import AppKit
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

private struct ModelBrandIcon: View {
    let model: String
    var providerType: String = ""
    var provider: String = ""
    var size: CGFloat = 13

    var body: some View {
        if let brand = ModelBrand.resolve(model: model, providerType: providerType, provider: provider) {
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
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
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
                            isMiniProbeFeatureEnabled: state.providerMiniProbeEnabled,
                            isMiniProbeEnabled: state.isProviderMiniProbeEnabled(provider),
                            isMiniProbeRunning: state.isProviderMiniProbeRunning(provider),
                            miniProbeHistory: state.providerMiniProbeHistory(for: provider),
                            miniProbeAverageTTFB: state.providerMiniProbeAverageTTFB(for: provider),
                            miniProbeModel: state.providerMiniProbeModel(for: provider),
                            resolvedMiniProbeModel: state.resolvedProviderMiniProbeModelTitle(for: provider),
                            setMiniProbeEnabled: { value in
                                state.setProviderMiniProbe(provider, enabled: value)
                            },
                            setMiniProbeModel: { model in
                                state.setProviderMiniProbeModel(model, for: provider)
                            },
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
    @State private var isAutoSyncPopoverPresented = false
    @State private var isRateRefreshHovered = false
    @State private var isBalanceRefreshHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                header
                RefreshHairline(isActive: state.isRefreshingUpstreamRates || state.isRefreshingUpstreamBalances)
            }
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
            await state.refreshUpstreamBalances(silent: true)
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
                Text("按官网聚合同一上游；勾选后跟随上游自动应用")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 0) {
                Button {
                    Task { await state.refreshUpstreamRates() }
                } label: {
                    if state.isRefreshingUpstreamRates {
                        ProgressView()
                            .scaleEffect(0.48)
                            .frame(width: 24, height: 22)
                    } else {
                        Image(systemName: isRateRefreshHovered ? "arrow.clockwise" : "list.bullet.rectangle")
                            .font(.system(size: 10.5, weight: .bold))
                            .frame(width: 24, height: 22)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isRateRefreshHovered ? theme.accentBlue : theme.textSecondary)
                .disabled(state.isRefreshingUpstreamRates)
                .help("重新检测 key 匹配和分组倍率")
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isRateRefreshHovered = hovering
                    }
                }

                Rectangle()
                    .fill(theme.borderSubtle)
                    .frame(width: 1, height: 12)

                Button {
                    Task { await state.refreshUpstreamBalances() }
                } label: {
                    if state.isRefreshingUpstreamBalances {
                        ProgressView()
                            .scaleEffect(0.48)
                            .frame(width: 24, height: 22)
                    } else {
                        Image(systemName: isBalanceRefreshHovered ? "arrow.clockwise" : "creditcard")
                            .font(.system(size: 10.5, weight: .bold))
                            .frame(width: 24, height: 22)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isBalanceRefreshHovered ? theme.accentBlue : theme.textSecondary)
                .disabled(state.isRefreshingUpstreamBalances)
                .help(upstreamBalanceRefreshHelp(state.upstreamBalanceLastRefreshedAt))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isBalanceRefreshHovered = hovering
                    }
                }

                Rectangle()
                    .fill(theme.borderSubtle)
                    .frame(width: 1, height: 12)

                Button {
                    isAutoSyncPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: state.upstreamRateAutoSyncEnabled ? "timer.circle.fill" : "timer")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(state.upstreamRateAutoSyncEnabled ? "\(Int(state.upstreamRateAutoSyncIntervalHours))h" : "自动")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                }
                .buttonStyle(.borderless)
                .fixedSize()
                .foregroundStyle(state.upstreamRateAutoSyncEnabled ? theme.accentBlue : theme.textSecondary)
                .help("自动检测/同步频率")
                .popover(isPresented: $isAutoSyncPopoverPresented, arrowEdge: .bottom) {
                    UpstreamAutoSyncPopover(state: state)
                        .environment(\.cchTheme, theme)
                }
            }
            .padding(.horizontal, 1)
            .cchSurface(.control)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            MiniStat(title: "官网", value: "\(state.upstreamRateSites.count)")
            MiniStat(title: "可同步", value: "\(state.upstreamRateSyncableSites.count)")
            MiniStat(title: "跟随", value: "\(state.upstreamRateCheckedSyncCount)")
            MiniStat(
                title: "待应用",
                value: Text("\(state.upstreamRatePendingSyncCount)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.22), value: state.upstreamRatePendingSyncCount)
                    .foregroundStyle(state.upstreamRatePendingSyncCount > 0 ? theme.accentOrange : theme.textPrimary),
                highlighted: state.upstreamRatePendingSyncCount > 0
            )
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: state.upstreamRatePendingSyncCount)
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
                .animation(.easeOut(duration: 0.16), value: sites.map(\.id))
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
            .animation(.easeOut(duration: 0.16), value: state.upstreamRateUnsupportedSites.map(\.id))
        }
    }
}

private struct UpstreamAutoSyncPopover: View {
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme
    @State private var intervalInput = ""

    private var normalizedHours: Double? {
        guard let hours = Int(intervalInput), hours > 0 else { return nil }
        return Double(min(max(hours, 1), 72))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("自动同步")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Toggle("", isOn: $state.upstreamRateAutoSyncEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.72)
                    .onChange(of: state.upstreamRateAutoSyncEnabled) { _, _ in
                        state.startUpstreamRateAutoSyncTimer()
                    }
            }

            HStack(spacing: 8) {
                TextField("小时", text: $intervalInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(width: 74)
                    .onChange(of: intervalInput) { _, value in
                        let digits = value.filter(\.isNumber)
                        if digits != value {
                            intervalInput = String(digits.prefix(2))
                        } else if digits.count > 2 {
                            intervalInput = String(digits.prefix(2))
                        }
                    }
                    .onSubmit {
                        applyInterval()
                    }
                Text("小时")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("保存") {
                    applyInterval()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(theme.accentBlue)
                .disabled(normalizedHours == nil)
            }

            if state.upstreamRateAutoSyncEnabled {
                AutoSyncCountdown(state: state)
            }

            Text("范围 1-72；余额后台每 1 小时静默刷新。")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 230)
        .onAppear {
            intervalInput = multiplierInputString(state.upstreamRateAutoSyncIntervalHours)
        }
    }

    private func applyInterval() {
        guard let normalizedHours else { return }
        state.upstreamRateAutoSyncIntervalHours = normalizedHours
        intervalInput = "\(Int(normalizedHours))"
        state.startUpstreamRateAutoSyncTimer(resetSchedule: true)
    }
}

private struct AutoSyncCountdown: View {
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme
    @State private var now = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var nextRun: Date? { state.upstreamRateAutoSyncNextRunAt }

    private var progress: Double {
        guard let next = nextRun else { return 0 }
        let interval = state.upstreamRateAutoSyncIntervalHours * 3600
        guard interval > 0 else { return 0 }
        let scheduledAt = next.addingTimeInterval(-interval)
        let elapsed = max(0, now.timeIntervalSince(scheduledAt))
        return min(1, elapsed / interval)
    }

    private var remainingText: String {
        guard let next = nextRun else { return "等待首次自动同步" }
        let remaining = next.timeIntervalSince(now)
        if remaining <= 0 { return "即将同步…" }
        let totalMinutes = Int(remaining / 60)
        if totalMinutes < 1 { return "< 1m" }
        if totalMinutes < 60 { return "\(totalMinutes)m" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("距下次同步")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(remainingText)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.25), value: remainingText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.borderSubtle.opacity(0.5))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.accentBlue, theme.accentBlue.opacity(0.45)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(3, geo.size.width * progress))
                }
            }
            .frame(height: 3)
            .clipShape(Capsule())
        }
        .onReceive(timer) { _ in now = Date() }
        .onAppear { now = Date() }
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
    @State private var isEditingDisplayName = false
    @State private var draftDisplayName = ""
    @State private var isConfirmingDelete = false

    private var stripColor: Color {
        if site.pendingSyncCount > 0 { return theme.accentOrange }
        if configureCredential != nil { return theme.accentBlue.opacity(0.55) }
        if site.status == .available { return theme.accentGreen }
        return theme.textTertiary.opacity(0.4)
    }

    private var subtitleText: Text {
        let base = Text("\(site.matchedCount)/\(site.rows.count) key 已匹配 · \(site.selectedCount) 个跟随")
        guard site.lastSyncAdjustedCount > 0 else { return base }
        return base
            + Text(" · 本轮已调整 ")
            + Text("\(site.lastSyncAdjustedCount)")
                .foregroundStyle(theme.accentGreen)
                .fontWeight(.semibold)
            + Text(" 个")
    }

    private static let stripHeight: CGFloat = 26

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
                    UpstreamHostTitleEditor(
                        host: site.host,
                        displayName: site.displayName,
                        sourceType: site.sourceType,
                        isEditing: $isEditingDisplayName,
                        draftName: $draftDisplayName,
                        fontSize: 12,
                        save: { name in
                            state.setUpstreamRateHostDisplayName(host: site.host, displayName: name)
                        }
                    )
                    subtitleText
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    if let balance = site.balance {
                        UpstreamBalanceCapsule(balance: balance)
                    }
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
                        StatusCapsule(text: "\(site.pendingSyncCount) 待应用", color: theme.accentOrange)
                    } else if site.status == .available {
                        StatusCapsule(text: "已检测", color: theme.accentGreen)
                    } else {
                        StatusCapsule(text: "需登录", color: theme.accentOrange)
                    }
                    Button {
                        isConfirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9.5, weight: .bold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentRed.opacity(0.92))
                    .help("从上游倍率移除此官网")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditingDisplayName {
                    toggleExpanded?()
                }
            }

            if !isCollapsible || isExpanded {
                ForEach(site.rows) { row in
                    UpstreamRateProviderSyncRow(row: row, state: state)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            }
        }
        .padding(10)
        .padding(.leading, 3)
        .cchSurface(.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderSubtle, lineWidth: 1))
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(stripColor)
                .frame(width: 3, height: Self.stripHeight)
                .padding(.top, 9)
        }
        .animation(.easeOut(duration: 0.16), value: isExpanded)
        .transition(.opacity.combined(with: .scale(scale: 0.992, anchor: .top)))
        .confirmationDialog(
            "从上游倍率移除 \(site.displayName)？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("移除", role: .destructive) {
                state.deleteUpstreamRateSite(site)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这只会隐藏这个官网分组，不会删除 CCH 渠道。")
        }
    }
}

private enum UpstreamBalanceTier {
    case healthy   // >= $5
    case low       // $1 .. $5
    case critical  // < $1

    init(_ amount: Double) {
        if amount < 1 { self = .critical }
        else if amount < 5 { self = .low }
        else { self = .healthy }
    }
}

private struct UpstreamBalanceCapsule: View {
    let balance: UpstreamBalanceSnapshot
    @Environment(\.cchTheme) private var theme

    private var tier: UpstreamBalanceTier {
        UpstreamBalanceTier(balance.displayAmount)
    }

    private var textColor: Color {
        switch tier {
        case .healthy:  return .white
        case .low:      return theme.accentOrange
        case .critical: return theme.accentRed
        }
    }

    var body: some View {
        Text(upstreamBalanceText(balance))
            .font(.system(size: 11.5, weight: .black, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: balance.displayAmount))
            .animation(.easeOut(duration: 0.3), value: balance.displayAmount)
            .foregroundStyle(textColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Color.black.opacity(0.88))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.7))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .help(upstreamBalanceHelp(balance))
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

private struct UpstreamRateProviderSyncRow: View {
    let row: UpstreamRateProviderRow
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme
    @State private var modelTestInput = ""
    @State private var multiplierInput = ""
    @State private var renderedEditor: ProviderEditor?
    @State private var editorRevealHeight: CGFloat = 0

    private enum ProviderEditor: Equatable {
        case multiplier
        case modelTest
    }

    private var statusColor: Color {
        switch row.matchStatus {
        case .matched: return row.hasRateChange ? theme.accentOrange : theme.accentGreen
        case .unmatched: return theme.textTertiary
        case .unsupported: return theme.textTertiary
        }
    }

    private var provider: CCHProvider? {
        state.provider(forUpstreamRateRow: row)
    }

    private var rateDirection: RateChangeDirection {
        guard let upstreamRate = row.upstreamRate else { return .none }
        if abs(row.currentRate - upstreamRate) < 0.0001 { return .equal }
        return row.currentRate > upstreamRate ? .up : .down
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                StatusDot(color: statusColor)
                    .frame(width: 12)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(row.providerName)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                        UpstreamHostBadge(host: row.host, isInteractive: true) {
                            openUpstreamHost(row.host)
                        }
                        if let group = row.upstreamGroupName {
                            UpstreamGroupBadge(group: group)
                        }
                    }
                    HStack(spacing: 6) {
                        Text("当前")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                        if let provider, !row.isSelectedForSync {
                            Button {
                                toggleMultiplierEditor(provider)
                            } label: {
                                if state.isProviderMultiplierUpdating(provider) {
                                    ProgressView()
                                        .scaleEffect(0.42)
                                        .frame(width: 26, height: 14)
                                } else {
                                    MultiplierBadge(value: row.currentRate, compact: true)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isProviderMultiplierUpdating(provider))
                            .help("手动编辑 CCH 倍率")
                        } else {
                            MultiplierBadge(value: row.currentRate, compact: true)
                                .help(row.isSelectedForSync ? "正在跟随上游，取消勾选后可手动编辑" : "")
                        }
                        if let upstreamRate = row.upstreamRate {
                            RateChangeArrow(direction: rateDirection)
                            Text("上游")
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                            MultiplierBadge(value: upstreamRate, compact: true)
                        } else {
                            Text(row.matchStatus == .matched ? "未跟随，可手动编辑 CCH 倍率" : "暂未匹配上游 key")
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 6)
                if let provider {
                    Button {
                        toggleModelTest(provider)
                    } label: {
                        if state.isProviderModelTesting(provider) {
                            ProgressView()
                                .scaleEffect(0.45)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 20, height: 20)
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentOrange)
                    .disabled(state.isProviderModelTesting(provider))
                    .help("供应商模型测试")
                }

                Button {
                    Task { await state.toggleUpstreamRateSyncSelection(row) }
                } label: {
                    Image(systemName: row.isSelectedForSync ? "checkmark.square.fill" : "square")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18, height: 20)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(row.isSelectedForSync ? theme.accentBlue : theme.textTertiary)
                .disabled(row.matchStatus != .matched)
                .help(row.isSelectedForSync ? "取消跟随上游" : "跟随上游，倍率变化后自动应用")
            }

            if let provider, let renderedEditor {
                ProviderEditorReveal(
                    revealHeight: editorRevealHeight,
                    contentHeight: editorHeight(renderedEditor, provider: provider)
                ) {
                    ProviderInlineEditorContainer {
                        switch renderedEditor {
                        case .multiplier:
                            ProviderMultiplierPopover(
                                provider: provider,
                                multiplier: $multiplierInput,
                                isUpdating: state.isProviderMultiplierUpdating(provider)
                            ) { value in
                                closeEditor()
                                Task { await state.updateProviderMultiplier(provider, multiplier: value) }
                            }
                        case .modelTest:
                            ProviderModelTestPopover(
                                provider: provider,
                                model: $modelTestInput,
                                isTesting: state.isProviderModelTesting(provider),
                                result: state.providerModelTestResult(for: provider),
                                resultsByModel: state.providerModelTestResults(for: provider),
                                progress: state.providerModelTestProgress(for: provider),
                                customModels: state.customTestModels(for: provider),
                                addModel: { model in state.addCustomTestModel(model, for: provider) },
                                removeModel: { model in state.removeCustomTestModel(model, for: provider) },
                                runSingle: { model in Task { await state.testProviderModel(provider, model: model) } },
                                runBatch: { models in Task { await state.testProviderModels(provider, models: models) } }
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            ZStack {
                theme.row
                if row.wasAdjustedInLastSync {
                    theme.accentGreen.opacity(0.08)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(.easeOut(duration: 0.18), value: row.wasAdjustedInLastSync)
        .onChange(of: provider.map { state.customTestModels(for: $0) } ?? []) {
            guard renderedEditor == .modelTest, let provider else { return }
            editorRevealHeight = editorHeight(.modelTest, provider: provider)
        }
        .onChange(of: row.isSelectedForSync) { _, selected in
            if selected {
                if renderedEditor == .multiplier {
                    closeEditor()
                }
            }
        }
    }

    private func toggleModelTest(_ provider: CCHProvider) {
        if modelTestInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelTestInput = provider.testModel
        }
        toggleEditor(.modelTest, provider: provider)
    }

    private func toggleMultiplierEditor(_ provider: CCHProvider) {
        if multiplierInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            multiplierInput = multiplierInputString(row.currentRate)
        }
        toggleEditor(.multiplier, provider: provider)
    }

    private func toggleEditor(_ editor: ProviderEditor, provider: CCHProvider) {
        if renderedEditor == editor, editorRevealHeight > 0 {
            closeEditor()
            return
        }

        let targetHeight = editorHeight(editor, provider: provider)
        if renderedEditor == nil {
            renderedEditor = editor
            editorRevealHeight = 0
            withAnimation(editorOpenAnimation) {
                editorRevealHeight = targetHeight
            }
        } else {
            renderedEditor = editor
            withAnimation(editorOpenAnimation) {
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

    private func editorHeight(_ editor: ProviderEditor, provider: CCHProvider) -> CGFloat {
        switch editor {
        case .multiplier:
            return 70
        case .modelTest:
            return state.customTestModels(for: provider).isEmpty ? 76 : 112
        }
    }

    private var editorCloseAnimation: Animation {
        .easeInOut(duration: 0.2)
    }

    private var editorOpenAnimation: Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.24)
    }
}

private struct UpstreamRateUnsupportedCard: View {
    let site: UpstreamRateSite
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme
    @State private var isEditingDisplayName = false
    @State private var draftDisplayName = ""
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(color: theme.textTertiary)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 4) {
                UpstreamHostTitleEditor(
                    host: site.host,
                    displayName: site.displayName,
                    sourceType: nil,
                    isEditing: $isEditingDisplayName,
                    draftName: $draftDisplayName,
                    fontSize: 11.5,
                    trailing: {
                        StatusCapsule(text: "仅展示", color: theme.textTertiary)
                    },
                    save: { name in
                        state.setUpstreamRateHostDisplayName(host: site.host, displayName: name)
                    }
                )
                Text(site.rows.map(\.providerName).joined(separator: "、"))
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 4) {
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
                Button {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9.5, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.accentRed.opacity(0.92))
                .help("从上游倍率移除此官网")
            }
        }
        .padding(10)
        .cchSurface(.panelSoft)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(theme.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        )
        .opacity(0.72)
        .transition(.opacity.combined(with: .scale(scale: 0.992, anchor: .top)))
        .confirmationDialog(
            "从上游倍率移除 \(site.displayName)？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("移除", role: .destructive) {
                state.deleteUpstreamRateSite(site)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这只会隐藏这个官网分组，不会删除 CCH 渠道。")
        }
    }
}

private struct UpstreamHostTitleEditor<Trailing: View>: View {
    let host: String
    let displayName: String
    let sourceType: UpstreamRateSourceType?
    @Binding var isEditing: Bool
    @Binding var draftName: String
    var fontSize: CGFloat
    @ViewBuilder var trailing: () -> Trailing
    let save: (String) -> Void
    @Environment(\.cchTheme) private var theme

    init(
        host: String,
        displayName: String,
        sourceType: UpstreamRateSourceType?,
        isEditing: Binding<Bool>,
        draftName: Binding<String>,
        fontSize: CGFloat,
        @ViewBuilder trailing: @escaping () -> Trailing,
        save: @escaping (String) -> Void
    ) {
        self.host = host
        self.displayName = displayName
        self.sourceType = sourceType
        _isEditing = isEditing
        _draftName = draftName
        self.fontSize = fontSize
        self.trailing = trailing
        self.save = save
    }

    var body: some View {
        HStack(spacing: 6) {
            if isEditing {
                TextField(host, text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: fontSize, weight: .semibold))
                    .frame(minWidth: 120, maxWidth: 190)
                    .onSubmit {
                        commit()
                    }
                Button {
                    commit()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.accentBlue)
                .help("保存名称")
                Button {
                    cancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .black))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.textSecondary)
                .help("取消")
            } else {
                Text(displayName)
                    .font(.system(size: fontSize, weight: .semibold))
                    .lineLimit(1)
                if displayName != host {
                    UpstreamHostBadge(host: host, isInteractive: true) {
                        openUpstreamHost(host)
                    }
                }
                Button {
                    beginEditing()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 8.5, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.textTertiary)
                .help("自定义上游名称")
            }
            if let sourceType {
                UpstreamSourceBadge(type: sourceType)
            }
            trailing()
        }
    }

    private func beginEditing() {
        draftName = displayName == host ? "" : displayName
        isEditing = true
    }

    private func commit() {
        save(draftName)
        isEditing = false
    }

    private func cancel() {
        draftName = ""
        isEditing = false
    }
}

private extension UpstreamHostTitleEditor where Trailing == EmptyView {
    init(
        host: String,
        displayName: String,
        sourceType: UpstreamRateSourceType?,
        isEditing: Binding<Bool>,
        draftName: Binding<String>,
        fontSize: CGFloat,
        save: @escaping (String) -> Void
    ) {
        self.init(
            host: host,
            displayName: displayName,
            sourceType: sourceType,
            isEditing: isEditing,
            draftName: draftName,
            fontSize: fontSize,
            trailing: { EmptyView() },
            save: save
        )
    }
}

private struct UpstreamHostBadge: View {
    let host: String
    var isInteractive = false
    var action: (() -> Void)?
    @Environment(\.cchTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "globe")
                    .font(.system(size: 7.5, weight: .bold))
                Text(host)
                    .lineLimit(1)
                if isInteractive {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 6.8, weight: .black))
                        .opacity(isHovering ? 1 : 0.58)
                }
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(isHovering && isInteractive ? theme.backgroundBottom : theme.accentBlue)
            .padding(.horizontal, isInteractive ? 6 : 5)
            .padding(.vertical, 1.5)
            .background(theme.accentBlue.opacity(isHovering && isInteractive ? 0.95 : 0.11))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.accentBlue.opacity(isHovering && isInteractive ? 0.75 : 0.25), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .offset(y: isHovering && isInteractive ? -0.5 : 0)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .help(isInteractive ? "打开 \(host)" : host)
        .animation(.easeInOut(duration: 0.14), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
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
    let highlighted: Bool
    @Environment(\.cchTheme) private var theme

    init(title: String, value: String, highlighted: Bool = false) {
        self.title = title
        self.highlighted = highlighted
        self.value = AnyView(
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.22), value: value)
        )
    }

    init<V: View>(title: String, value: V, highlighted: Bool = false) {
        self.title = title
        self.highlighted = highlighted
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
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.accentOrange.opacity(highlighted ? 0.55 : 0), lineWidth: 1)
        )
        .shadow(color: theme.accentOrange.opacity(highlighted ? 0.18 : 0), radius: 3)
        .animation(.easeOut(duration: 0.2), value: highlighted)
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
    let top: Int
    let bottom: Int
    let topColor: Color
    let bottomColor: Color
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(top > 0 ? compactNumber(top) : "-")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(top > 0 ? topColor : theme.textTertiary)
                .monospacedDigit()
            Text(bottom > 0 ? compactNumber(bottom) : "-")
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(bottom > 0 ? bottomColor : theme.textTertiary.opacity(0.82))
                .monospacedDigit()
        }
        .frame(width: 44, alignment: .trailing)
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

private struct CappedInlineText: View {
    let text: String
    let maxWidth: CGFloat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: maxWidth, alignment: .leading)
        }
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
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, compact ? 4 : 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.13))
            .clipShape(Capsule())
            .contentTransition(.numericText(value: value))
            .animation(.easeOut(duration: 0.28), value: value)
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
                    if log.costUsd > 0 {
                        Text("·")
                            .fixedSize(horizontal: true, vertical: false)
                        MoneyValue(value: log.costUsd, majorSize: 10.5, minorSize: 6.5, weight: .semibold, color: theme.textSecondary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
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

    var providerTitle: String {
        log.providerName.isEmpty ? "渠道" : log.providerName
    }

    var modelTitle: String {
        model.isEmpty ? "模型" : model
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
                    CappedInlineText(text: providerTitle, maxWidth: 220)
                        .font(.system(size: 11.5, weight: .semibold))
                        .layoutPriority(1)
                    MultiplierBadge(value: providerMultiplier, compact: true)
                        .fixedSize(horizontal: true, vertical: false)
                    if log.isFastTier {
                        FastTierBadge(compact: true)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    StatusCapsule(text: statusText, color: statusColor)
                        .fixedSize(horizontal: true, vertical: false)
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
                    CappedInlineText(text: modelTitle, maxWidth: 200)
                        .layoutPriority(1)
                    Text("· \(shortTime(log.createdAt))")
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            CompactUsageMetric(
                top: log.outputTokens,
                bottom: log.inputTokens,
                topColor: theme.textPrimary,
                bottomColor: theme.textSecondary
            )
            CompactUsageMetric(
                top: log.cacheCreationTokens,
                bottom: log.cacheReadTokens,
                topColor: cacheCreationDisplayColor(cacheStatus, theme: theme),
                bottomColor: cacheReadDisplayColor(cacheStatus, theme: theme)
            )
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
                        providerType: provider.providerType,
                        provider: provider.name,
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
    let isMiniProbeFeatureEnabled: Bool
    let isMiniProbeEnabled: Bool
    let isMiniProbeRunning: Bool
    let miniProbeHistory: [CCHProviderMiniProbeSample]
    let miniProbeAverageTTFB: Double?
    let miniProbeModel: String
    let resolvedMiniProbeModel: String
    let setMiniProbeEnabled: (Bool) -> Void
    let setMiniProbeModel: (String) -> Void
    let addCustomTestModel: (String) -> Void
    let removeCustomTestModel: (String) -> Void
    let resetCircuit: () -> Void
    @State private var modelTestInput = ""
    @State private var multiplierInput = ""
    @State private var miniProbeModelInput = ""
    @State private var renderedEditor: ProviderEditor?
    @State private var editorRevealHeight: CGFloat = 0
    @Environment(\.cchTheme) private var theme

    private enum ProviderEditor: Equatable {
        case multiplier
        case miniProbe
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
                                providerType: provider.providerType,
                                provider: provider.name,
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
                    ProviderMiniProbeControl(
                        featureEnabled: isMiniProbeFeatureEnabled,
                        isEnabled: isMiniProbeEnabled,
                        isRunning: isMiniProbeRunning,
                        samples: miniProbeHistory,
                        averageTTFB: miniProbeAverageTTFB,
                        resolvedModel: resolvedMiniProbeModel,
                        toggle: {
                            setMiniProbeEnabled(!isMiniProbeEnabled)
                        },
                        edit: {
                            miniProbeModelInput = miniProbeModel
                            toggleEditor(.miniProbe)
                        }
                    )
                    Button {
                        probe()
                    } label: {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentOrange)
                    .help("测速")
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
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentOrange)
                    .disabled(isModelTesting)
                    .help("供应商模型测试")
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
                            case .miniProbe:
                                ProviderMiniProbePopover(
                                    provider: provider,
                                    model: $miniProbeModelInput,
                                    resolvedModel: resolvedMiniProbeModel,
                                    featureEnabled: isMiniProbeFeatureEnabled,
                                    isEnabled: isMiniProbeEnabled,
                                    isRunning: isMiniProbeRunning,
                                    samples: miniProbeHistory,
                                    averageTTFB: miniProbeAverageTTFB,
                                    setEnabled: setMiniProbeEnabled
                                ) { value in
                                    closeEditor()
                                    setMiniProbeModel(value)
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
            editorRevealHeight = editorHeight(.modelTest)
        }
        .onChange(of: miniProbeModel) {
            guard renderedEditor == .miniProbe else { return }
            miniProbeModelInput = miniProbeModel
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
            withAnimation(editorOpenAnimation) {
                editorRevealHeight = targetHeight
            }
        } else {
            renderedEditor = editor
            withAnimation(editorOpenAnimation) {
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
        case .miniProbe:
            return 128
        case .modelTest:
            return customTestModels.isEmpty ? 76 : 112
        }
    }

    private var editorCloseAnimation: Animation {
        .easeInOut(duration: 0.2)
    }

    private var editorOpenAnimation: Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.24)
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
        .frame(height: max(0, min(revealHeight, contentHeight)), alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .allowsHitTesting(revealHeight > 0.5)
        .accessibilityHidden(revealHeight <= 0)
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

private struct ProviderMiniProbeControl: View {
    let featureEnabled: Bool
    let isEnabled: Bool
    let isRunning: Bool
    let samples: [CCHProviderMiniProbeSample]
    let averageTTFB: Double?
    let resolvedModel: String
    let toggle: () -> Void
    let edit: () -> Void
    @Environment(\.cchTheme) private var theme
    @State private var isEditHovered = false

    private var active: Bool {
        featureEnabled && isEnabled
    }

    private var latestSample: CCHProviderMiniProbeSample? {
        samples.max { $0.createdAt < $1.createdAt }
    }

    private var statusColor: Color {
        guard active else { return theme.textTertiary }
        if isRunning { return theme.accentBlue }
        return latestSample.map { providerMiniProbeColor($0.status, theme: theme) } ?? theme.accentBlue
    }

    private var helpText: String {
        if !featureEnabled {
            return "Mini 探针未开启，请在设置中启用"
        }
        let status = isEnabled ? "已开启" : "已关闭"
        let average = averageTTFB.map { " · 平均首字节 \(formatProbeLatency($0))" } ?? ""
        return "Mini 探针\(status) · \(resolvedModel)\(average)"
    }

    private var editButtonColor: Color {
        guard featureEnabled else { return theme.textTertiary }
        return isEditHovered ? theme.accentOrange : theme.textSecondary
    }

    var body: some View {
        HStack(spacing: 4) {
            ProviderMiniProbeNeedles(samples: samples, active: active, isRunning: isRunning)
                .frame(width: 28, height: 14)
                .help(helpText)

            if let averageTTFB {
                Text(formatProbeLatency(averageTTFB))
                    .font(.system(size: 9.2, weight: .bold, design: .rounded))
                    .foregroundStyle(active ? statusColor : theme.textTertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .help("平均首字节 \(formatProbeLatency(averageTTFB))")
            }

            Button {
                toggle()
            } label: {
                Group {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.42)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                }
                .frame(width: 18, height: 18)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isRunning)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(statusColor)
            .disabled(!featureEnabled)
            .help(helpText)

            Button {
                edit()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isEditHovered && featureEnabled ? theme.accentOrange.opacity(0.16) : Color.clear)
                    )
            }
            .buttonStyle(.borderless)
            .foregroundStyle(editButtonColor)
            .help("设置此渠道探针模型")
            .onHover { hovering in
                isEditHovered = hovering
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(active ? statusColor.opacity(0.08) : theme.textTertiary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(active ? statusColor.opacity(0.42) : theme.borderSubtle, lineWidth: 1)
        )
    }
}

private struct ProviderMiniProbeNeedles: View {
    let samples: [CCHProviderMiniProbeSample]
    let active: Bool
    let isRunning: Bool
    @Environment(\.cchTheme) private var theme
    @State private var runningPulse = false

    private var orderedSamples: [CCHProviderMiniProbeSample] {
        Array(samples.sorted { $0.createdAt < $1.createdAt }.suffix(CCHProviderMiniProbeLimits.maxSamples))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 1.4) {
            ForEach(0..<CCHProviderMiniProbeLimits.maxSamples, id: \.self) { index in
                let leadingEmpty = max(0, CCHProviderMiniProbeLimits.maxSamples - orderedSamples.count)
                let sample = index >= leadingEmpty ? orderedSamples[index - leadingEmpty] : nil
                Capsule()
                    .fill(color(for: sample, index: index))
                    .frame(width: 2, height: height(for: sample, index: index))
                    .opacity(opacity(for: sample, index: index))
                    .scaleEffect(sample == nil ? 0.86 : 1, anchor: .bottom)
                    .animation(.spring(response: 0.32, dampingFraction: 0.78), value: orderedSamples.map(\.id))
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: runningPulse)
            }
        }
        .onAppear {
            runningPulse = isRunning
        }
        .onChange(of: isRunning) { _, value in
            runningPulse = value
        }
    }

    private func color(for sample: CCHProviderMiniProbeSample?, index: Int) -> Color {
        if isRunning, index == CCHProviderMiniProbeLimits.maxSamples - 1 {
            return theme.accentBlue
        }
        guard let sample else { return theme.textTertiary.opacity(0.34) }
        return providerMiniProbeColor(sample.status, theme: theme)
    }

    private func opacity(for sample: CCHProviderMiniProbeSample?, index: Int) -> Double {
        if isRunning, index == CCHProviderMiniProbeLimits.maxSamples - 1 {
            return runningPulse ? 0.42 : 1
        }
        return active || sample != nil ? 1 : 0.55
    }

    private func height(for sample: CCHProviderMiniProbeSample?, index: Int) -> CGFloat {
        if isRunning, index == CCHProviderMiniProbeLimits.maxSamples - 1 {
            return 7
        }
        return sample == nil ? 4 : 7
    }
}

private struct ProviderMiniProbePopover: View {
    let provider: CCHProvider
    @Binding var model: String
    let resolvedModel: String
    let featureEnabled: Bool
    let isEnabled: Bool
    let isRunning: Bool
    let samples: [CCHProviderMiniProbeSample]
    let averageTTFB: Double?
    let setEnabled: (Bool) -> Void
    let saveModel: (String) -> Void
    @Environment(\.cchTheme) private var theme

    private var normalizedModel: String {
        normalizedProviderTestModel(model)
    }

    private var latestSample: CCHProviderMiniProbeSample? {
        samples.sorted { $0.createdAt < $1.createdAt }.last
    }

    private var latestText: String {
        guard let latestSample else { return "暂无样本" }
        let totalLatency = latestSample.latencyMs.map(formatProbeLatency) ?? "-"
        let relativeTime = formatRelativeShortTime(latestSample.createdAt)
        if let ttfbMs = providerMiniProbeSuccessTTFBMs(
            isSuccess: latestSample.status == .success,
            ttfbMs: latestSample.ttfbMs
        ) {
            return "\(probeStatusTitle(latestSample.status)) · 首字节 \(formatProbeLatency(ttfbMs)) · 总延迟 \(totalLatency) · \(relativeTime)"
        }
        return "\(probeStatusTitle(latestSample.status)) · 总延迟 \(totalLatency) · \(relativeTime)"
    }

    private var averageText: String? {
        averageTTFB.map { "平均首字节 \(formatProbeLatency($0))" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(featureEnabled && isEnabled ? theme.accentOrange : theme.textTertiary)
                    .frame(width: 18)
                Text("Mini 探针")
                    .font(.system(size: 11.5, weight: .semibold))
                ProviderMiniProbeNeedles(
                    samples: samples,
                    active: featureEnabled && isEnabled,
                    isRunning: isRunning
                )
                .frame(width: 30, height: 14)
                Text(latestText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.62)
                .disabled(!featureEnabled)
            }

            if let averageText {
                HStack(spacing: 4) {
                    Image(systemName: "timer.circle")
                        .font(.system(size: 10, weight: .semibold))
                    Text(averageText)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(theme.textSecondary)
            }

            HStack(spacing: 8) {
                TextField("此渠道探针模型", text: $model)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .medium))
                    .onSubmit {
                        saveModel(normalizedModel)
                    }
                Button("恢复") {
                    model = ""
                    saveModel("")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(normalizedModel.isEmpty)
                Button("保存") {
                    saveModel(normalizedModel)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(theme.accentOrange)
            }

            Text(featureEnabled ? "当前使用 \(resolvedModel)" : "设置中开启总开关后才会发起后台模型测试。当前使用 \(resolvedModel)")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            model = normalizedProviderTestModel(model)
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
        let timing = formatProviderModelTestTiming(result)
        let displayModel = result.model.isEmpty ? normalizedModel : result.model
        let detail = result.errorMessage.isEmpty ? result.message : result.errorMessage
        if result.success || result.status.lowercased() == "green" || result.status.lowercased() == "yellow" {
            return "\(timing) · \(displayModel)"
        }
        return detail.isEmpty ? displayModel : detail
    }

    private var statusId: String {
        if isTesting { return "testing" }
        guard let result else { return "idle" }
        return "\(result.status)-\(result.success)-\(result.model)-\(result.errorMessage)-\(result.ttfbMs ?? -1)-\(result.latencyMs ?? -1)"
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
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(canAddModel ? theme.accentGreen.opacity(0.18) : theme.textTertiary.opacity(0.1))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 34, height: 34)
                                .contentShape(Rectangle())
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(canAddModel ? theme.accentGreen : theme.textTertiary)
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
                    Group {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.55)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(!canRun || isTesting ? theme.accentOrange.opacity(0.36) : theme.accentOrange)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
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
            if let ttfbMs = result.ttfbMs {
                return formatProbeLatency(ttfbMs)
            }
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

private struct RefreshHairline: View {
    let isActive: Bool
    @State private var phase: CGFloat = 0   // 0 = off left, 1 = off right
    @State private var measuredWidth: CGFloat = 0
    @State private var isCycling = false
    @State private var keepCycling = false
    @Environment(\.cchTheme) private var theme

    private let cycleDuration: Double = 1.4

    private var bandWidth: CGFloat {
        max(60, measuredWidth * 0.42)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.borderSubtle.opacity(0.4))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, theme.accentBlue, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: bandWidth)
                    .offset(x: -bandWidth + phase * (geo.size.width + bandWidth))
            }
            .onAppear { measuredWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, new in measuredWidth = new }
        }
        .frame(height: 1.5)
        .clipShape(Capsule())
        .opacity(isCycling ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: isCycling)
        .onAppear {
            keepCycling = isActive
            if isActive && !isCycling { startCycle() }
        }
        .onChange(of: isActive) { _, new in
            keepCycling = new
            if new && !isCycling { startCycle() }
        }
    }

    private func startCycle() {
        isCycling = true
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            phase = 0
        }
        DispatchQueue.main.async {
            withAnimation(.linear(duration: cycleDuration)) {
                phase = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + cycleDuration + 0.01) {
            if keepCycling {
                startCycle()
            } else {
                isCycling = false
            }
        }
    }
}

private enum RateChangeDirection {
    case up, down, equal, none
}

private struct RateChangeArrow: View {
    let direction: RateChangeDirection
    @Environment(\.cchTheme) private var theme

    private var symbolName: String {
        switch direction {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .equal: return "equal"
        case .none: return "arrow.right"
        }
    }

    private var color: Color {
        switch direction {
        case .up: return theme.accentGreen
        case .down: return theme.accentOrange
        case .equal, .none: return theme.textSecondary
        }
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(color)
            .frame(width: 14, height: 12)
            .contentTransition(.symbolEffect(.replace))
            .animation(.easeOut(duration: 0.18), value: direction)
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

private func providerMiniProbeColor(_ status: CCHProviderMiniProbeStatus, theme: CCHThemePalette) -> Color {
    switch status {
    case .success: return theme.accentGreen
    case .warning: return theme.accentOrange
    case .failure: return theme.accentRed
    }
}

private func probeStatusTitle(_ status: CCHProviderMiniProbeStatus) -> String {
    switch status {
    case .success: return "可用"
    case .warning: return "波动"
    case .failure: return "失败"
    }
}

private func upstreamBalanceText(_ balance: UpstreamBalanceSnapshot) -> String {
    let value = balance.displayAmount
    let formatted: String
    switch abs(value) {
    case 0..<10:
        formatted = String(format: "%.2f", value)
    case 10..<1000:
        formatted = String(format: "%.1f", value)
    default:
        formatted = String(format: "%.0f", value)
    }
    return balance.unit == "USD" ? "$\(formatted)" : "\(formatted) \(balance.unit)"
}

private func upstreamBalanceHelp(_ balance: UpstreamBalanceSnapshot) -> String {
    var parts = ["余额 \(upstreamBalanceText(balance))"]
    if let rawAmount = balance.rawAmount {
        parts.append("raw \(String(format: "%.0f", rawAmount))")
    }
    if let used = balance.usedDisplayAmount {
        parts.append("已用 $\(String(format: "%.2f", used))")
    }
    if let totalRecharged = balance.totalRechargedDisplayAmount {
        parts.append("累计充值 $\(String(format: "%.2f", totalRecharged))")
    }
    return parts.joined(separator: " · ")
}

private func upstreamBalanceRefreshHelp(_ lastRefreshedAt: Date?) -> String {
    guard let lastRefreshedAt else {
        return "刷新上游账户余额"
    }
    return "刷新上游账户余额 · 上次 \(formatRelativeShortTime(lastRefreshedAt))"
}

private func formatRelativeShortTime(_ date: Date, now: Date = Date()) -> String {
    let seconds = max(0, now.timeIntervalSince(date))
    if seconds < 60 {
        return "刚刚"
    }
    if seconds < 3600 {
        return "\(Int(seconds / 60)) 分钟前"
    }
    if seconds < 86_400 {
        return "\(Int(seconds / 3600)) 小时前"
    }
    return "\(Int(seconds / 86_400)) 天前"
}

private func openUpstreamHost(_ host: String) {
    guard let url = upstreamHostURL(host) else { return }
    NSWorkspace.shared.open(url)
}

private func upstreamHostURL(_ host: String) -> URL? {
    let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed), url.scheme != nil {
        return url
    }
    return URL(string: "https://\(trimmed)")
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
