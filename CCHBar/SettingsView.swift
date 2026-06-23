import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: MonitorState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var refreshStatus: SettingsRefreshStatus = .idle
    @State private var revealToken = false
    @State private var showAdvancedConnection = false
    @State private var draftCCHBaseURL = ""
    @State private var draftCCHToken = ""
    @State private var draftCCHEnvPath = ""
    @State private var isApplyingConnection = false
    @State private var launchError: String?
    @State private var miniProbeIntervalPreview: Double?
    @State private var miniProbeAveragePreview: Double?
    @State private var miniProbeScheduleStartPreview: Double?
    @State private var miniProbeScheduleEndPreview: Double?
    private var theme: CCHThemePalette { state.selectedTheme.palette }

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(state: state)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    connectionCard
                    syncCard
                    probeCard
                    appearanceCard
                    updateCard
                    systemCard
                    aboutCard
                }
                .padding(18)
            }
        }
        .frame(width: 620, height: 560)
        .background(SettingsBackground())
        .foregroundStyle(theme.textPrimary)
        .environment(\.cchTheme, theme)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loadConnectionDrafts()
        }
    }

    private var hasConnectionChanges: Bool {
        draftCCHBaseURL != state.cchBaseURL
            || draftCCHToken != state.cchToken
            || draftCCHEnvPath != state.cchEnvPath
    }

    private var connectionCard: some View {
        SettingsCard(
            icon: "link.circle.fill",
            title: "连接",
            subtitle: "配置 Claude Code Hub 反代地址和访问密钥。",
            accent: theme.accentBlue
        ) {
            SettingsControlRow(title: "服务地址", subtitle: "用于打开页面和请求 API。") {
                SettingsInputField(text: $draftCCHBaseURL, placeholder: "https://cch.example.com/", isURL: true)
            }

            SettingsControlRow(title: "API Key", subtitle: revealToken ? "当前处于明文显示，确认后建议关闭。" : "默认隐藏，点击右侧按钮可完整显示。") {
                TokenInputField(text: $draftCCHToken, revealToken: $revealToken)
            }

            DisclosureGroup(isExpanded: $showAdvancedConnection) {
                SettingsControlRow(title: "Env 文件", subtitle: "只作为备用读取来源；应用不会自动写入。") {
                    SettingsInputField(text: $draftCCHEnvPath, placeholder: "/path/to/local.env")
                }
                .padding(.top, 8)
            } label: {
                Label("高级连接来源", systemImage: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .toggleStyle(.button)

            HStack(spacing: 10) {
                Button {
                    runConnectionCheck()
                } label: {
                    Label(isApplyingConnection ? "验证中" : "测试连接", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isApplyingConnection)

                SettingsStatusPill(status: refreshStatus, errorMessage: state.errorMessage)
                Spacer()

                if hasConnectionChanges {
                    Text("未应用")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accentOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accentOrange.opacity(0.12))
                        .clipShape(Capsule())
                }

                Button {
                    applyConnectionSettings()
                } label: {
                    Label(isApplyingConnection ? "应用中" : "应用", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(theme.accentBlue)
                .disabled(!hasConnectionChanges || isApplyingConnection)
            }
        }
    }

    private var syncCard: some View {
        SettingsCard(
            icon: "arrow.triangle.2.circlepath.circle.fill",
            title: "同步",
            subtitle: "控制后台快照和状态栏筛选。",
            accent: theme.accentPurple
        ) {
            SettingsControlRow(title: "活跃用户", subtitle: "只在状态栏关注指定用户；留空表示全部。") {
                SettingsInputField(text: $state.activeSessionUserFilter, placeholder: "用户名称，可留空")
            }

            SettingsControlRow(title: "状态栏轮询", subtitle: "空闲用于发现新任务，活跃用于任务进行中的状态更新。") {
                HStack(spacing: 8) {
                    Text("空闲")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    Picker("", selection: Binding(
                        get: {
                            CCHActiveSessionRefreshInterval.sanitizedIdleSeconds(state.activeSessionIdleRefreshIntervalSeconds)
                        },
                        set: { seconds in
                            state.setActiveSessionIdleRefreshIntervalSeconds(seconds)
                        }
                    )) {
                        ForEach(CCHActiveSessionRefreshInterval.allowedIdleSeconds, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 132)

                    Text("活跃")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    Picker("", selection: Binding(
                        get: {
                            CCHActiveSessionRefreshInterval.sanitizedActiveSeconds(state.activeSessionActiveRefreshIntervalSeconds)
                        },
                        set: { seconds in
                            state.setActiveSessionActiveRefreshIntervalSeconds(seconds)
                        }
                    )) {
                        ForEach(CCHActiveSessionRefreshInterval.allowedActiveSeconds, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 90)
                }
            }

            SettingsControlRow(title: "后台刷新", subtitle: "抽屉打开时当前页会更频繁同步。") {
                HStack(spacing: 10) {
                    Slider(value: $state.refreshInterval, in: 8...120, step: 1)
                        .tint(theme.accentPurple)
                    Text("\(Int(state.refreshInterval))s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.accentPurple)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            .onChange(of: state.refreshInterval) { _, _ in
                state.startRefreshTimer()
            }

            SettingsControlRow(title: "顶栏信息", subtitle: "刘海屏可一键收起秒数和缓存灯，状态栏会自动缩短。") {
                SettingsTrailingToggle(label: "显示详情", isOn: $state.showStatusBarDetails)
            }
            .onChange(of: state.showStatusBarDetails) { _, _ in
                state.refreshStatusBarSnapshotForPreferencesChange()
            }

            SettingsControlRow(title: "低功耗动效", subtitle: "关闭状态栏运行光环、滚动文字和缓存呼吸灯；默认保留完整特效。") {
                SettingsTrailingToggle(label: "低功耗", isOn: $state.statusBarReducedMotion)
            }
            .onChange(of: state.statusBarReducedMotion) { _, _ in
                state.refreshStatusBarSnapshotForPreferencesChange()
            }

            HStack(spacing: 10) {
                SettingsInfoPill(icon: "play.circle.fill", title: "运行中", value: "\(state.menuBarRunningLogs.count)")
                SettingsInfoPill(icon: "server.rack", title: "渠道", value: "\(state.enabledProviderCount)/\(state.providers.count)")
                SettingsInfoPill(icon: "clock", title: "最近", value: state.lastRefresh.map { $0.formatted(date: .omitted, time: .shortened) } ?? "-")
                Spacer()
                Button {
                    runFullRefresh()
                } label: {
                    Label("立即同步", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(state.isLoading)
            }
        }
    }

    private var probeCard: some View {
        SettingsCard(
            icon: "waveform.path.ecg",
            title: "Mini 探针",
            subtitle: "复用供应商模型测试，记录每个渠道最近 8 次结果。",
            accent: theme.accentOrange
        ) {
            MiniProbePanel {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("启用探针")
                            .font(.system(size: 13, weight: .semibold))
                        Text(state.providerMiniProbeEnabled ? "只会探测已单独开启的渠道，关闭后不会发起后台模型测试请求。" : "关闭后不会发起后台模型测试请求。")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Toggle("", isOn: $state.providerMiniProbeEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: state.providerMiniProbeEnabled) { _, enabled in
                            state.startProviderMiniProbeTimer(runImmediately: enabled, forceImmediate: enabled)
                        }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                MiniProbePanel(isMuted: !state.providerMiniProbeEnabled) {
                    MiniProbeControlHeader(
                        title: "探针频率",
                        subtitle: "每个已开启渠道按这个间隔执行一次模型测试。",
                        value: "\(Int(miniProbeIntervalPreview ?? state.providerMiniProbeIntervalMinutes))m",
                        valueActive: state.providerMiniProbeEnabled
                    )
                    MiniProbeValueSlider(
                        value: $state.providerMiniProbeIntervalMinutes,
                        previewValue: $miniProbeIntervalPreview,
                        range: CCHProviderMiniProbeLimits.minIntervalMinutes...CCHProviderMiniProbeLimits.maxIntervalMinutes,
                        step: 5,
                        ticks: [
                            MiniProbeSliderTick(value: 5, label: "5m"),
                            MiniProbeSliderTick(value: 60, label: "1h"),
                            MiniProbeSliderTick(value: 180, label: "3h"),
                            MiniProbeSliderTick(value: 360, label: "6h")
                        ],
                        isEnabled: state.providerMiniProbeEnabled
                    ) {
                        state.normalizeProviderMiniProbeInterval()
                        state.restartProviderMiniProbeTimerDebounced()
                    }
                }
                MiniProbePanel(isMuted: !state.providerMiniProbeEnabled) {
                    MiniProbeControlHeader(
                        title: "平均首字",
                        subtitle: "按最近有首字节数据的探针样本计算平均值。",
                        value: "\(miniProbeAverageDisplayCount)次",
                        valueActive: state.providerMiniProbeEnabled && state.providerMiniProbeAverageTTFBEnabled
                    ) {
                        MiniProbeToggle(
                            isOn: $state.providerMiniProbeAverageTTFBEnabled,
                            isEnabled: state.providerMiniProbeEnabled
                        )
                    }
                    MiniProbeValueSlider(
                        value: $state.providerMiniProbeAverageSampleCount,
                        previewValue: $miniProbeAveragePreview,
                        range: CCHProviderMiniProbeLimits.minAverageSampleCount...CCHProviderMiniProbeLimits.maxAverageSampleCount,
                        step: 1,
                        ticks: [
                            MiniProbeSliderTick(value: 1, label: "1"),
                            MiniProbeSliderTick(value: 3, label: "3"),
                            MiniProbeSliderTick(value: 5, label: "5"),
                            MiniProbeSliderTick(value: 8, label: "8")
                        ],
                        isEnabled: state.providerMiniProbeEnabled && state.providerMiniProbeAverageTTFBEnabled
                    ) {
                        state.normalizeProviderMiniProbeAverageSampleCount()
                    }
                }
            }

            MiniProbePanel(isMuted: !state.providerMiniProbeEnabled) {
                MiniProbeControlHeader(
                    title: "运行时段",
                    subtitle: "关闭限制时全天 24 小时运行；开启后只在选中的时段运行。",
                    value: miniProbeScheduleDisplayText,
                    valueActive: state.providerMiniProbeEnabled && state.providerMiniProbeScheduleEnabled
                ) {
                    MiniProbeToggle(
                        isOn: $state.providerMiniProbeScheduleEnabled,
                        isEnabled: state.providerMiniProbeEnabled
                    )
                    .onChange(of: state.providerMiniProbeScheduleEnabled) { _, _ in
                        state.normalizeProviderMiniProbeSchedule()
                    }
                }
                ProviderMiniProbeTimeRangeSlider(
                    startHour: $state.providerMiniProbeScheduleStartHour,
                    endHour: $state.providerMiniProbeScheduleEndHour,
                    previewStartHour: $miniProbeScheduleStartPreview,
                    previewEndHour: $miniProbeScheduleEndPreview,
                    isEnabled: state.providerMiniProbeEnabled && state.providerMiniProbeScheduleEnabled
                ) {
                    state.normalizeProviderMiniProbeSchedule()
                }
                .frame(height: 50)
                .opacity(state.providerMiniProbeEnabled && state.providerMiniProbeScheduleEnabled ? 1 : 0.55)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    providerMiniProbeInfoPills
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        SettingsInfoPill(icon: "switch.2", title: "渠道", value: "\(state.providerMiniProbeSelectedCount)")
                        SettingsInfoPill(icon: "waveform.path.ecg", title: "样本", value: "\(state.providerMiniProbeRecordedSampleCount)")
                        SettingsInfoPill(icon: "timer", title: "频率", value: "\(Int(miniProbeIntervalPreview ?? state.providerMiniProbeIntervalMinutes))m")
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 10) {
                        SettingsInfoPill(icon: "clock", title: "时段", value: miniProbeScheduleDisplayText)
                        SettingsInfoPill(icon: "timer.circle", title: "首字", value: state.providerMiniProbeAverageTTFBEnabled ? "\(miniProbeAverageDisplayCount)次" : "关")
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var providerMiniProbeInfoPills: some View {
        SettingsInfoPill(icon: "switch.2", title: "渠道", value: "\(state.providerMiniProbeSelectedCount)")
        SettingsInfoPill(icon: "waveform.path.ecg", title: "样本", value: "\(state.providerMiniProbeRecordedSampleCount)")
        SettingsInfoPill(icon: "timer", title: "频率", value: "\(Int(miniProbeIntervalPreview ?? state.providerMiniProbeIntervalMinutes))m")
        SettingsInfoPill(icon: "clock", title: "时段", value: miniProbeScheduleDisplayText)
        SettingsInfoPill(icon: "timer.circle", title: "首字", value: state.providerMiniProbeAverageTTFBEnabled ? "\(miniProbeAverageDisplayCount)次" : "关")
    }

    private var miniProbeAverageDisplayCount: Int {
        Int(min(
            max((miniProbeAveragePreview ?? state.providerMiniProbeAverageSampleCount).rounded(), CCHProviderMiniProbeLimits.minAverageSampleCount),
            CCHProviderMiniProbeLimits.maxAverageSampleCount
        ))
    }

    private var miniProbeScheduleDisplayText: String {
        guard state.providerMiniProbeScheduleEnabled else { return "全天" }
        let start = min(max(miniProbeScheduleStartPreview ?? state.providerMiniProbeScheduleStartHour, 0), 24)
        let end = min(max(miniProbeScheduleEndPreview ?? state.providerMiniProbeScheduleEndHour, 0), 24)
        if start <= 0, end >= 24 { return "全天" }
        if abs(start - end) < 0.001 { return "已停用" }
        let suffix = start > end ? " 次日" : ""
        return "\(formatProviderMiniProbeHour(start))-\(formatProviderMiniProbeHour(end))\(suffix)"
    }

    private var updateCard: some View {
        SettingsCard(
            icon: "arrow.down.app.fill",
            title: "更新",
            subtitle: "检查新版本并提醒下载。",
            accent: theme.accentGreen
        ) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动检查更新")
                        .font(.system(size: 13, weight: .semibold))
                    Text(state.checkForUpdatesEnabled
                         ? "每 6 小时检查一次，发现新版后在状态栏弹窗底部提醒。"
                         : "已关闭。可在下方手动触发检查。")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $state.checkForUpdatesEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: state.checkForUpdatesEnabled) { _, newValue in
                        state.startUpdateCheckTimer()
                        if newValue {
                            Task { await state.checkForUpdates(force: true) }
                        }
                    }
            }

            HStack(spacing: 10) {
                SettingsInfoPill(icon: "app.badge", title: "当前", value: "v\(state.appVersion)")
                if let update = state.availableUpdate {
                    SettingsInfoPill(icon: "sparkles", title: "新版", value: "v\(update.version)")
                }
                if let last = state.lastUpdateCheck {
                    SettingsInfoPill(icon: "clock", title: "检查", value: last.formatted(date: .omitted, time: .shortened))
                }
                Spacer()
                Button {
                    Task { await state.checkForUpdates(force: true) }
                } label: {
                    if state.isCheckingForUpdate {
                        Label("检查中", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("立即检查", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(state.isCheckingForUpdate)
            }

            if let update = state.availableUpdate {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(theme.accentGreen)
                        Text(update.displayName)
                            .font(.system(size: 13, weight: .semibold))
                        if let publishedAt = update.publishedAt {
                            Text(publishedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                    }
                    if !update.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(update.body)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        Spacer()
                        Button("跳过此版本") {
                            state.dismissAvailableUpdate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button {
                            state.openLatestRelease()
                        } label: {
                            Label("打开下载页", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(theme.accentGreen)
                    }
                }
                .padding(11)
                .background(theme.accentGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.accentGreen.opacity(0.3), lineWidth: 1)
                )
            } else if let error = state.updateCheckError {
                Text("检查失败：\(error)")
                    .font(.caption)
                    .foregroundStyle(theme.accentOrange)
            }
        }
    }

    private var systemCard: some View {
        SettingsCard(
            icon: "macwindow.on.rectangle",
            title: "系统",
            subtitle: "控制启动项和常用入口。",
            accent: theme.accentOrange
        ) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("开机启动")
                        .font(.system(size: 13, weight: .semibold))
                    Text(launchAtLogin ? "登录后自动启动菜单栏监控。" : "关闭后需要手动打开应用。")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }

            if let launchError {
                Text(launchError)
                    .font(.caption)
                    .foregroundStyle(theme.accentOrange)
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("退出", systemImage: "power")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var appearanceCard: some View {
        SettingsCard(
            icon: "paintpalette.fill",
            title: "外观",
            subtitle: "切换菜单栏面板和设置窗口的皮肤。",
            accent: state.selectedTheme == .endlessDark ? theme.accentBlue : .cyan
        ) {
            SettingsControlRow(title: "主题", subtitle: "Liquid Glass 保留当前玻璃质感，Endless Dark 使用深色外壳。") {
                HStack(spacing: 10) {
                    ForEach(CCHTheme.allCases) { item in
                        SettingsThemeButton(
                            themeOption: item,
                            isSelected: state.selectedTheme == item
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                state.selectedTheme = item
                            }
                        }
                    }
                }
            }
        }
    }

    private var aboutCard: some View {
        SettingsCard(
            icon: "info.circle.fill",
            title: "关于",
            subtitle: "Claude Code Hub 的轻量菜单栏看板。",
            accent: theme.accentMint
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    SettingsInfoPill(icon: "app.badge", title: "版本", value: "v\(state.appVersion)")
                    SettingsInfoPill(icon: "doc.text", title: "许可证", value: "MIT")
                    Spacer()
                }

                Text("用于快速查看 Claude Code Hub 的运行中请求、最近日志、排行和渠道状态，并提供轻量入口打开主项目页面。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Copyright (c) 2026 xt1990xt1990。复制、分发、修改或二次开发时，请保留原始版权声明、MIT 许可证文本和 NOTICE 中的署名信息。")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 7) {
                SettingsLinkRow(
                    icon: "shippingbox.fill",
                    title: "Claude Code Hub Bar",
                    subtitle: "原项目与 MIT 署名说明",
                    url: URL(string: "https://github.com/xt1990xt1990/Claude-Code-Hub-Bar")!,
                    accent: theme.accentMint
                )
                SettingsLinkRow(
                    icon: "server.rack",
                    title: "Claude Code Hub",
                    subtitle: "打开主项目",
                    url: URL(string: "https://github.com/ding113/claude-code-hub")!,
                    accent: theme.accentBlue
                )
                SettingsLinkRow(
                    icon: "sparkles",
                    title: "LobeHub Icons",
                    subtitle: "模型图标来源",
                    url: URL(string: "https://github.com/lobehub/lobe-icons")!,
                    accent: theme.accentPurple
                )
            }
        }
    }

    private func loadConnectionDrafts() {
        draftCCHBaseURL = state.cchBaseURL
        draftCCHToken = state.cchToken
        draftCCHEnvPath = state.cchEnvPath
    }

    private func applyConnectionSettings() {
        refreshStatus = .checking
        isApplyingConnection = true

        state.cchBaseURL = draftCCHBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        state.cchToken = draftCCHToken.trimmingCharacters(in: .whitespacesAndNewlines)
        state.cchEnvPath = draftCCHEnvPath.trimmingCharacters(in: .whitespacesAndNewlines)
        loadConnectionDrafts()

        Task {
            await state.refresh()
            refreshStatus = state.errorMessage == nil ? .success : .failed
            isApplyingConnection = false
        }
    }

    private func runConnectionCheck() {
        applyConnectionSettings()
    }

    private func runFullRefresh() {
        Task {
            await state.refresh()
            refreshStatus = state.errorMessage == nil ? .success : .failed
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        launchError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchError = "启动项更新失败：\(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private enum SettingsRefreshStatus: Equatable {
    case idle
    case checking
    case success
    case failed
}

private struct SettingsHeader: View {
    @ObservedObject var state: MonitorState
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 13) {
            CCHLogoMark(size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Claude Code Hub")
                        .font(.system(size: 17, weight: .semibold))
                    SettingsTinyBadge(
                        text: state.errorMessage == nil ? "已连接" : "需检查",
                        color: state.errorMessage == nil ? theme.accentGreen : theme.accentOrange
                    )
                }
                Text("菜单栏控制面板")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                MoneyValue(value: state.overview.todayCost, majorSize: 18, minorSize: 10, weight: .bold)
                    .contentTransition(.numericText())
                Text("\(compactNumber(state.overview.todayRequests)) 次请求")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
        .background {
            if theme.prefersGlassEffects {
                Rectangle().fill(.ultraThinMaterial)
            } else {
                Rectangle().fill(theme.headerBackground)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.hairline)
                .frame(height: 1)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent: Color
    @ViewBuilder let content: () -> Content
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(0.16))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(15)
        .background {
            if theme.prefersGlassEffects {
                Rectangle().fill(.regularMaterial)
            } else {
                Rectangle().fill(theme.panel)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.34), theme.border, theme.borderSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: accent.opacity(0.08), radius: 18, y: 8)
    }
}

private struct SettingsControlRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 142, alignment: .leading)

            content()
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SettingsTrailingToggle: View {
    let label: String
    @Binding var isOn: Bool
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(width: 220, alignment: .trailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct SettingsInputField: View {
    @Binding var text: String
    let placeholder: String
    var isURL = false
    @Environment(\.cchTheme) private var theme

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder))
            .textFieldStyle(.plain)
            .textContentType(isURL ? .URL : .none)
            .font(.system(size: 12.5, design: isURL ? .monospaced : .default))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .cchSurface(.input)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.borderStrong, lineWidth: 1)
            )
    }
}

private struct TokenInputField: View {
    @Binding var text: String
    @Binding var revealToken: Bool
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if revealToken {
                    TextEditor(text: $text)
                        .font(.system(size: 11.5, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(minHeight: 68, maxHeight: 82)
                        .cchSurface(.input)
                } else {
                    SecureField("", text: $text, prompt: Text("API Key"))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, design: .monospaced))
                        .padding(.leading, 10)
                        .padding(.trailing, 42)
                        .frame(height: 32)
                        .cchSurface(.input)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        revealToken.toggle()
                    }
                } label: {
                    Image(systemName: revealToken ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(revealToken ? theme.accentOrange : theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(revealToken ? "隐藏 API Key" : "完整显示 API Key")
                .padding(.trailing, 3)
                .padding(.top, 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(revealToken ? theme.accentOrange.opacity(0.32) : theme.borderStrong, lineWidth: 1)
            )
        }
    }
}

private struct SettingsStatusPill: View {
    let status: SettingsRefreshStatus
    let errorMessage: String?
    @Environment(\.cchTheme) private var theme

    var body: some View {
        let text: String = {
            switch status {
            case .idle:
                return errorMessage == nil ? "等待验证" : "上次异常"
            case .checking:
                return "正在验证"
            case .success:
                return "连接正常"
            case .failed:
                return "连接异常"
            }
        }()
        let color: Color = {
            switch status {
            case .idle:
                return errorMessage == nil ? theme.textSecondary : theme.accentOrange
            case .checking:
                return theme.accentBlue
            case .success:
                return theme.accentGreen
            case .failed:
                return theme.accentOrange
            }
        }()

        HStack(spacing: 5) {
            if status == .checking {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.18), value: status)
    }
}

private struct MiniProbePanel<Content: View>: View {
    var isMuted = false
    @ViewBuilder let content: () -> Content
    @Environment(\.cchTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cchSurface(.row)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .opacity(isMuted ? 0.62 : 1)
    }
}

private struct MiniProbeControlHeader<Accessory: View>: View {
    let title: String
    let subtitle: String
    let value: String
    let valueActive: Bool
    @ViewBuilder var accessory: () -> Accessory
    @Environment(\.cchTheme) private var theme

    init(
        title: String,
        subtitle: String,
        value: String,
        valueActive: Bool,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.valueActive = valueActive
        self.accessory = accessory
    }

    init(
        title: String,
        subtitle: String,
        value: String,
        valueActive: Bool
    ) where Accessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.valueActive = valueActive
        self.accessory = { EmptyView() }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                accessory()
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 10)
            Text(value)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueActive ? theme.accentOrange : theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct MiniProbeToggle: View {
    @Binding var isOn: Bool
    let isEnabled: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(!isEnabled)
            .frame(width: 50, alignment: .leading)
    }
}

private struct MiniProbeSliderTick: Identifiable {
    let value: Double
    let label: String

    var id: Double { value }
}

private struct MiniProbeValueSlider: View {
    @Binding var value: Double
    @Binding var previewValue: Double?
    let range: ClosedRange<Double>
    let step: Double
    let ticks: [MiniProbeSliderTick]
    let isEnabled: Bool
    let onCommit: () -> Void
    @Environment(\.cchTheme) private var theme
    @State private var draftValue: Double
    @State private var isEditing = false

    init(
        value: Binding<Double>,
        previewValue: Binding<Double?>,
        range: ClosedRange<Double>,
        step: Double,
        ticks: [MiniProbeSliderTick],
        isEnabled: Bool,
        onCommit: @escaping () -> Void
    ) {
        self._value = value
        self._previewValue = previewValue
        self.range = range
        self.step = step
        self.ticks = ticks
        self.isEnabled = isEnabled
        self.onCommit = onCommit
        self._draftValue = State(initialValue: value.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 2) {
            Slider(
                value: $draftValue,
                in: range,
                step: step,
                onEditingChanged: { editing in
                    isEditing = editing
                    if editing {
                        draftValue = value
                        previewValue = draftValue
                    } else {
                        let committedValue = clampedValue(draftValue)
                        draftValue = committedValue
                        value = committedValue
                        previewValue = nil
                        onCommit()
                    }
                }
            )
                .tint(theme.accentOrange)
                .disabled(!isEnabled)
                .frame(height: 20)
                .onChange(of: value) { _, newValue in
                    guard !isEditing else { return }
                    draftValue = newValue
                    previewValue = nil
                }
                .onChange(of: draftValue) { _, newValue in
                    guard isEditing else { return }
                    previewValue = clampedValue(newValue)
                }
                .onChange(of: isEnabled) { _, enabled in
                    guard !enabled else { return }
                    isEditing = false
                    draftValue = value
                    previewValue = nil
                }
            MiniProbeSliderScale(range: range, ticks: ticks, isEnabled: isEnabled)
        }
        .opacity(isEnabled ? 1 : 0.58)
    }

    private func clampedValue(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct MiniProbeSliderScale: View {
    let range: ClosedRange<Double>
    let ticks: [MiniProbeSliderTick]
    let isEnabled: Bool
    @Environment(\.cchTheme) private var theme

    private let labelWidth: CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            let usableWidth = max(1, proxy.size.width - labelWidth)
            ZStack(alignment: .leading) {
                ForEach(ticks) { tick in
                    VStack(spacing: 3) {
                        Rectangle()
                            .fill(theme.textTertiary.opacity(isEnabled ? 0.36 : 0.20))
                            .frame(width: 1, height: 5)
                        Text(tick.label)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isEnabled ? theme.textTertiary : theme.textTertiary.opacity(0.62))
                    }
                    .frame(width: labelWidth)
                    .offset(x: tickOffset(tick.value, usableWidth: usableWidth))
                }
            }
        }
        .frame(height: 20)
    }

    private func tickOffset(_ value: Double, usableWidth: CGFloat) -> CGFloat {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard upper > lower else { return 0 }
        let ratio = min(max((value - lower) / (upper - lower), 0), 1)
        return CGFloat(ratio) * usableWidth
    }
}

private struct SettingsInfoPill: View {
    let icon: String
    let title: String
    let value: String
    @Environment(\.cchTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .cchSurface(.control)
        .clipShape(Capsule())
    }
}

private struct ProviderMiniProbeTimeRangeSlider: View {
    @Binding var startHour: Double
    @Binding var endHour: Double
    @Binding var previewStartHour: Double?
    @Binding var previewEndHour: Double?
    let isEnabled: Bool
    let onCommit: () -> Void
    @Environment(\.cchTheme) private var theme
    @State private var startDragBase: Double?
    @State private var endDragBase: Double?
    @State private var draftStartHour: Double?
    @State private var draftEndHour: Double?

    private let handleSize: CGFloat = 16
    private let ticks = [0, 6, 12, 18, 24]

    private var displayStartHour: Double {
        isEnabled ? min(max(draftStartHour ?? startHour, 0), 24) : 0
    }

    private var displayEndHour: Double {
        isEnabled ? min(max(draftEndHour ?? endHour, 0), 24) : 24
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width - handleSize)
            let startX = CGFloat(displayStartHour / 24) * width + handleSize / 2
            let endX = CGFloat(displayEndHour / 24) * width + handleSize / 2
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.textTertiary.opacity(0.18))
                    .frame(height: 7)
                    .padding(.horizontal, handleSize / 2)
                    .offset(y: -7)

                selectedRange(width: width, startX: startX, endX: endX)

                ForEach(ticks, id: \.self) { tick in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(theme.textTertiary.opacity(0.34))
                            .frame(width: 1, height: 6)
                        Text(tick == 24 ? "24" : "\(tick)")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(width: tickLabelWidth(for: tick), alignment: tickLabelAlignment(for: tick))
                    .offset(x: tickLabelOffset(for: tick, width: width), y: 10)
                }

                rangeHandle(title: formatProviderMiniProbeHour(displayStartHour), active: isEnabled)
                    .offset(x: startX - handleSize / 2, y: -7)
                    .gesture(startDrag(width: width))

                rangeHandle(title: formatProviderMiniProbeHour(displayEndHour), active: isEnabled)
                    .offset(x: endX - handleSize / 2, y: -7)
                    .gesture(endDrag(width: width))
            }
        }
    }

    private func tickLabelWidth(for tick: Int) -> CGFloat {
        tick == 0 || tick == 24 ? 18 : 24
    }

    private func tickLabelAlignment(for tick: Int) -> Alignment {
        if tick == 0 { return .leading }
        if tick == 24 { return .trailing }
        return .center
    }

    private func tickLabelOffset(for tick: Int, width: CGFloat) -> CGFloat {
        let x = CGFloat(Double(tick) / 24) * width + handleSize / 2
        if tick == 0 { return x - handleSize / 2 }
        if tick == 24 { return x - tickLabelWidth(for: tick) + handleSize / 2 }
        return x - tickLabelWidth(for: tick) / 2
    }

    private func rangeHandle(title: String, active: Bool) -> some View {
        Circle()
            .fill(active ? theme.accentOrange : theme.textTertiary)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.white.opacity(active ? 0.68 : 0.28), lineWidth: 1.2))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            .help(title)
    }

    private func startDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEnabled else { return }
                if startDragBase == nil {
                    startDragBase = startHour
                    draftStartHour = startHour
                    previewStartHour = startHour
                }
                let base = startDragBase ?? startHour
                let delta = Double(value.translation.width / max(width, 1)) * 24
                let draft = clampedHour(snappedHour(base + delta))
                draftStartHour = draft
                previewStartHour = draft
            }
            .onEnded { _ in
                if let draftStartHour {
                    startHour = draftStartHour
                    previewStartHour = nil
                    onCommit()
                }
                startDragBase = nil
                draftStartHour = nil
                previewStartHour = nil
            }
    }

    private func endDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEnabled else { return }
                if endDragBase == nil {
                    endDragBase = endHour
                    draftEndHour = endHour
                    previewEndHour = endHour
                }
                let base = endDragBase ?? endHour
                let delta = Double(value.translation.width / max(width, 1)) * 24
                let draft = clampedHour(snappedHour(base + delta))
                draftEndHour = draft
                previewEndHour = draft
            }
            .onEnded { _ in
                if let draftEndHour {
                    endHour = draftEndHour
                    previewEndHour = nil
                    onCommit()
                }
                endDragBase = nil
                draftEndHour = nil
                previewEndHour = nil
            }
    }

    private func snappedHour(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }

    private func clampedHour(_ value: Double) -> Double {
        min(max(value, 0), 24)
    }

    @ViewBuilder
    private func selectedRange(width: CGFloat, startX: CGFloat, endX: CGFloat) -> some View {
        let trackStart = handleSize / 2
        let trackEnd = width + handleSize / 2
        if displayStartHour <= displayEndHour {
            selectedRangeSegment(x: startX, width: endX - startX)
        } else {
            selectedRangeSegment(x: startX, width: trackEnd - startX)
            selectedRangeSegment(x: trackStart, width: endX - trackStart)
        }
    }

    private func selectedRangeSegment(x: CGFloat, width: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        isEnabled ? theme.accentOrange : theme.textTertiary.opacity(0.45),
                        isEnabled ? theme.accentOrange.opacity(0.62) : theme.textTertiary.opacity(0.28)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: max(0, width), height: 7)
            .offset(x: x, y: -7)
    }
}

private struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: URL
    let accent: Color
    @Environment(\.cchTheme) private var theme

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .cchSurface(.control)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsTinyBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.13))
            .clipShape(Capsule())
    }
}

private struct SettingsThemeButton: View {
    let themeOption: CCHTheme
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.cchTheme) private var theme

    private var accent: Color {
        themeOption == .endlessDark ? theme.accentBlue : .cyan
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(isSelected ? 0.22 : 0.12))
                    Image(systemName: themeOption.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(themeOption.displayName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Text(themeOption.summary)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(isSelected ? accent.opacity(0.12) : theme.control)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.42) : theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsBackground: View {
    @Environment(\.cchTheme) private var theme

    var body: some View {
        ZStack {
            theme.settingsBackgroundBase
            LinearGradient(
                colors: theme.settingsBackgroundOverlay,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
