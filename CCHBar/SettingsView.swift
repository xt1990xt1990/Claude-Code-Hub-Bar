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

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(state: state)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    connectionCard
                    syncCard
                    updateCard
                    systemCard
                }
                .padding(18)
            }
        }
        .frame(width: 620, height: 560)
        .background(SettingsBackground())
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
            accent: .blue
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
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }

                Button {
                    applyConnectionSettings()
                } label: {
                    Label(isApplyingConnection ? "应用中" : "应用", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.blue)
                .disabled(!hasConnectionChanges || isApplyingConnection)
            }
        }
    }

    private var syncCard: some View {
        SettingsCard(
            icon: "arrow.triangle.2.circlepath.circle.fill",
            title: "同步",
            subtitle: "控制后台快照和状态栏筛选。",
            accent: .purple
        ) {
            SettingsControlRow(title: "活跃用户", subtitle: "只在状态栏关注指定用户；留空表示全部。") {
                SettingsInputField(text: $state.activeSessionUserFilter, placeholder: "用户名称，可留空")
            }

            SettingsControlRow(title: "后台刷新", subtitle: "抽屉打开时当前页会更频繁同步。") {
                HStack(spacing: 10) {
                    Slider(value: $state.refreshInterval, in: 8...120, step: 1)
                        .tint(.purple)
                    Text("\(Int(state.refreshInterval))s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.purple)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            .onChange(of: state.refreshInterval) { _, _ in
                state.startRefreshTimer()
            }

            SettingsControlRow(title: "顶栏信息", subtitle: "刘海屏可一键收起秒数和缓存灯，状态栏会自动缩短。") {
                Toggle("显示详情", isOn: $state.showStatusBarDetails)
                    .toggleStyle(.switch)
                    .font(.system(size: 12, weight: .semibold))
            }
            .onChange(of: state.showStatusBarDetails) { _, _ in
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

    private var updateCard: some View {
        SettingsCard(
            icon: "arrow.down.app.fill",
            title: "更新",
            subtitle: "检查新版本并提醒下载。",
            accent: .green
        ) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动检查更新")
                        .font(.system(size: 13, weight: .semibold))
                    Text(state.checkForUpdatesEnabled
                         ? "每 6 小时检查一次，发现新版后在状态栏弹窗底部提醒。"
                         : "已关闭。可在下方手动触发检查。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $state.checkForUpdatesEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: state.checkForUpdatesEnabled) { _, newValue in
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
                            .foregroundStyle(.green)
                        Text(update.displayName)
                            .font(.system(size: 13, weight: .semibold))
                        if let publishedAt = update.publishedAt {
                            Text(publishedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if !update.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(update.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        .tint(.green)
                    }
                }
                .padding(11)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            } else if let error = state.updateCheckError {
                Text("检查失败：\(error)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var systemCard: some View {
        SettingsCard(
            icon: "macwindow.on.rectangle",
            title: "系统",
            subtitle: "控制启动项和常用入口。",
            accent: .orange
        ) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("开机启动")
                        .font(.system(size: 13, weight: .semibold))
                    Text(launchAtLogin ? "登录后自动启动菜单栏监控。" : "关闭后需要手动打开应用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.orange)
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

    var body: some View {
        HStack(spacing: 13) {
            CCHLogoMark(size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Claude Code Hub")
                        .font(.system(size: 17, weight: .semibold))
                    SettingsTinyBadge(
                        text: state.errorMessage == nil ? "已连接" : "需检查",
                        color: state.errorMessage == nil ? .green : .orange
                    )
                }
                Text("菜单栏控制面板")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                MoneyValue(value: state.overview.todayCost, majorSize: 18, minorSize: 10, weight: .bold)
                    .contentTransition(.numericText())
                Text("\(compactNumber(state.overview.todayRequests)) 次请求")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
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
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(15)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.34), Color.white.opacity(0.08), Color.black.opacity(0.08)],
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

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 142, alignment: .leading)

            content()
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SettingsInputField: View {
    @Binding var text: String
    let placeholder: String
    var isURL = false

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder))
            .textFieldStyle(.plain)
            .textContentType(isURL ? .URL : .none)
            .font(.system(size: 12.5, design: isURL ? .monospaced : .default))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct TokenInputField: View {
    @Binding var text: String
    @Binding var revealToken: Bool

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
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                } else {
                    SecureField("", text: $text, prompt: Text("API Key"))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, design: .monospaced))
                        .padding(.leading, 10)
                        .padding(.trailing, 42)
                        .frame(height: 32)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        revealToken.toggle()
                    }
                } label: {
                    Image(systemName: revealToken ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(revealToken ? .orange : .secondary)
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
                    .stroke(revealToken ? Color.orange.opacity(0.32) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }
}

private struct SettingsStatusPill: View {
    let status: SettingsRefreshStatus
    let errorMessage: String?

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
                return errorMessage == nil ? .secondary : .orange
            case .checking:
                return .blue
            case .success:
                return .green
            case .failed:
                return .orange
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

private struct SettingsInfoPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.58))
        .clipShape(Capsule())
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

private struct SettingsBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.13),
                    Color.purple.opacity(0.09),
                    Color.orange.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
