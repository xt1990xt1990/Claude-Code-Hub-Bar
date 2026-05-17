import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: MonitorState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var refreshStatus: SettingsRefreshStatus = .idle
    @State private var revealToken = false
    @State private var showAdvancedConnection = false
    @State private var launchError: String?

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(state: state)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    connectionCard
                    syncCard
                    systemCard
                }
                .padding(18)
            }
        }
        .frame(width: 620, height: 560)
        .background(SettingsBackground())
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var connectionCard: some View {
        SettingsCard(
            icon: "link.circle.fill",
            title: "连接",
            subtitle: "配置 Claude Code Hub 反代地址和访问密钥。",
            accent: .blue
        ) {
            SettingsControlRow(title: "服务地址", subtitle: "用于打开页面和请求 API。") {
                SettingsInputField(text: $state.cchBaseURL, placeholder: "https://cch.example.com/", isURL: true)
            }

            SettingsControlRow(title: "API Key", subtitle: revealToken ? "当前处于明文显示，确认后建议关闭。" : "默认隐藏，点击右侧按钮可完整显示。") {
            TokenInputField(text: $state.cchToken, revealToken: $revealToken)
            }

            DisclosureGroup(isExpanded: $showAdvancedConnection) {
                SettingsControlRow(title: "Env 文件", subtitle: "只作为备用读取来源；应用不会自动写入。") {
                    SettingsInputField(text: $state.cchEnvPath, placeholder: "/path/to/local.env")
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
                    Label(refreshStatus == .checking ? "验证中" : "测试连接", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(refreshStatus == .checking)

                SettingsStatusPill(status: refreshStatus, errorMessage: state.errorMessage)
                Spacer()
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

    private func runConnectionCheck() {
        refreshStatus = .checking
        Task {
            await state.refresh()
            refreshStatus = state.errorMessage == nil ? .success : .failed
        }
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
                Text(formatMoney(state.overview.todayCost))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
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
