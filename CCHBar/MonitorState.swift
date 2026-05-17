import AppKit
import Combine
import SwiftUI

enum CCHPanelTab: String, CaseIterable, Identifiable {
    case dashboard = "总览"
    case leaderboard = "排行"
    case logs = "日志"
    case providers = "渠道"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .leaderboard: return "chart.bar.xaxis"
        case .logs: return "list.bullet.rectangle"
        case .providers: return "server.rack"
        }
    }
}

enum CCHLeaderboardPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }
    var title: String {
        switch self {
        case .daily: return "今天"
        case .weekly: return "本周"
        case .monthly: return "本月"
        }
    }
}

enum CCHLeaderboardScope: String, CaseIterable, Identifiable {
    case user
    case model
    case provider

    var id: String { rawValue }
    var title: String {
        switch self {
        case .user: return "用户"
        case .model: return "模型"
        case .provider: return "渠道"
        }
    }
}

enum CCHLogRange: String, CaseIterable, Identifiable {
    case hour1
    case hours6
    case day1
    case day7
    case all

    var id: String { rawValue }
    var title: String {
        switch self {
        case .hour1: return "1h"
        case .hours6: return "6h"
        case .day1: return "24h"
        case .day7: return "7d"
        case .all: return "全部"
        }
    }

    var startDate: Date? {
        switch self {
        case .hour1: return Calendar.current.date(byAdding: .hour, value: -1, to: Date())
        case .hours6: return Calendar.current.date(byAdding: .hour, value: -6, to: Date())
        case .day1: return Calendar.current.date(byAdding: .day, value: -1, to: Date())
        case .day7: return Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .all: return nil
        }
    }
}

@MainActor
final class MonitorState: ObservableObject {
    @AppStorage("cch_base_url") var cchBaseURL = ""
    @AppStorage("cch_token") var cchToken = ""
    @AppStorage("cch_env_path") var cchEnvPath = ""
    @AppStorage("refreshInterval") var refreshInterval: Double = 15
    @AppStorage("active_session_user_filter") var activeSessionUserFilter = ""

    @Published var selectedTab: CCHPanelTab = .dashboard
    @Published var leaderboardPeriod: CCHLeaderboardPeriod = .daily
    @Published var leaderboardScope: CCHLeaderboardScope = .user
    @Published var logRange: CCHLogRange = .day1
    @Published var logModelFilter = ""
    @Published var logStatusFilter = ""
    @Published var logSessionFilter = ""
    @Published var selectedProviderGroups: Set<String> = []
    @Published var selectedLog: CCHLogEntry?

    @Published var overview = CCHOverview()
    @Published var activeSessions: [CCHActiveSession] = []
    @Published var recentLogs: [CCHLogEntry] = []
    @Published var leaderboard: [CCHLeaderboardEntry] = []
    @Published var logs: [CCHLogEntry] = []
    @Published var logSummary = CCHLogSummary()
    @Published var logTotal = 0
    @Published var providers: [CCHProvider] = []

    @Published var lastRefresh: Date?
    @Published var isLoading = false
    @Published var actionMessage: String?
    @Published var errorMessage: String?
    @Published var panelVisible = false

    private let api = APIService()
    private var refreshTimer: AnyCancellable?
    private var activeSessionTimer: AnyCancellable?
    private var focusedViewTimer: AnyCancellable?
    private var wakeObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var isLoadingActiveSessions = false
    private var isLoadingFocusedView = false

    var config: CCHConfig {
        CCHConfig(baseURL: cchBaseURL, token: cchToken, envPath: cchEnvPath)
    }

    var menuBarText: String {
        "TTL \(formatMoney(overview.todayCost))"
    }

    var providerMultiplierById: [Int: Double] {
        Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0.costMultiplier) })
    }

    var filteredActiveSessions: [CCHActiveSession] {
        let ordered = activeSessions.sorted { $0.startTime > $1.startTime }
        let filter = activeSessionUserFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !filter.isEmpty else { return ordered }
        return ordered.filter { $0.userName.lowercased().contains(filter) }
    }

    var menuBarActiveSessions: [CCHActiveSession] {
        let filtered = filteredActiveSessions
        return filtered.filter { session in
            session.concurrentCount > 0
                || session.durationMs <= 0
                || isRunningStatus(session.status)
        }
    }

    var menuBarRunningLogs: [CCHLogEntry] {
        let ordered = recentLogs
            .sorted { lhs, rhs in
                if lhs.id != rhs.id { return lhs.id > rhs.id }
                if lhs.requestSequence != rhs.requestSequence {
                    return lhs.requestSequence > rhs.requestSequence
                }
                return lhs.createdAt > rhs.createdAt
            }

        var seenSessionIds = Set<String>()
        return ordered.compactMap { log in
            guard log.statusCode == nil else { return nil }
            let key = log.sessionId.isEmpty ? "log-\(log.id)" : log.sessionId
            guard seenSessionIds.insert(key).inserted else { return nil }
            return log
        }
    }

    var currentMenuBarSession: CCHActiveSession? {
        menuBarActiveSessions.sorted { lhs, rhs in
            let lhsScore = menuBarActivityScore(lhs)
            let rhsScore = menuBarActivityScore(rhs)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.startTime > rhs.startTime
        }
        .first
    }

    var enabledProviderCount: Int {
        providers.filter(\.isEnabled).count
    }

    var unhealthyProviderCount: Int {
        providers.filter { $0.health.circuitState.lowercased() != "closed" || $0.health.failureCount > 0 }.count
    }

    var providerGroups: [String] {
        let groups = Set(providers.flatMap { providerGroupTitles($0.groupTag) })
        return ["全部"] + groups.filter { $0 != "全部" }.sorted()
    }

    var filteredProviders: [CCHProvider] {
        guard !selectedProviderGroups.isEmpty else { return providers }
        return providers.filter { provider in
            !Set(providerGroupTitles(provider.groupTag)).isDisjoint(with: selectedProviderGroups)
        }
    }

    var filteredEnabledProviderCount: Int {
        filteredProviders.filter(\.isEnabled).count
    }

    var filteredUnhealthyProviderCount: Int {
        filteredProviders.filter { $0.health.circuitState.lowercased() != "closed" || $0.health.failureCount > 0 }.count
    }

    init() {
        startRefreshTimer()
        startActiveSessionTimer()
        observeSystemWake()
        refreshTask = Task { await refresh() }
    }

    deinit {
        refreshTimer?.cancel()
        activeSessionTimer?.cancel()
        focusedViewTimer?.cancel()
        refreshTask?.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func providerMultiplier(for providerName: String) -> Double {
        let normalized = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return 1 }
        return providers.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(normalized) == .orderedSame
        })?.costMultiplier ?? 1
    }

    func isProviderGroupSelected(_ group: String) -> Bool {
        group == "全部" ? selectedProviderGroups.isEmpty : selectedProviderGroups.contains(group)
    }

    func toggleProviderGroup(_ group: String) {
        guard group != "全部" else {
            selectedProviderGroups = []
            return
        }

        var next = selectedProviderGroups
        if next.contains(group) {
            next.remove(group)
        } else {
            next.insert(group)
        }
        selectedProviderGroups = next
    }

    func startRefreshTimer() {
        refreshTimer?.cancel()
        let interval = max(8, refreshInterval)
        refreshTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshBackgroundSnapshot() }
            }
    }

    func startActiveSessionTimer() {
        activeSessionTimer?.cancel()
        activeSessionTimer = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshActiveSessionsOnly() }
            }
    }

    func setPanelVisible(_ visible: Bool) {
        panelVisible = visible
        if visible {
            startFocusedViewTimer()
            Task { await refreshFocusedView() }
        } else {
            focusedViewTimer?.cancel()
            focusedViewTimer = nil
        }
    }

    func startFocusedViewTimer() {
        focusedViewTimer?.cancel()
        focusedViewTimer = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshFocusedView() }
            }
    }

    func refresh() async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil

        async let overviewResult = loadOverview()
        async let sessionsResult = loadActiveSessions()
        async let leaderboardResult = loadLeaderboard()
        async let logsResult = loadLogs()
        async let providersResult = loadProviders()

        let errors = await [
            overviewResult,
            sessionsResult,
            leaderboardResult,
            logsResult,
            providersResult
        ].compactMap { $0 }

        if !errors.isEmpty {
            errorMessage = errors.joined(separator: " · ")
        }
        lastRefresh = Date()
        isLoading = false
    }

    func refreshBackgroundSnapshot() async {
        let errors = await [
            loadOverview(),
            loadProviders()
        ].compactMap { $0 }

        if !errors.isEmpty {
            errorMessage = errors.joined(separator: " · ")
        }
        lastRefresh = Date()
    }

    func refreshLogsOnly() async {
        isLoading = true
        errorMessage = await loadLogs()
        lastRefresh = Date()
        isLoading = false
    }

    func refreshLeaderboardOnly() async {
        isLoading = true
        errorMessage = await loadLeaderboard()
        lastRefresh = Date()
        isLoading = false
    }

    func refreshFocusedView() async {
        if isLoadingFocusedView { return }
        isLoadingFocusedView = true
        defer { isLoadingFocusedView = false }

        let error: String?
        switch selectedTab {
        case .dashboard:
            error = await loadOverview()
        case .logs:
            error = await loadLogs()
        case .leaderboard:
            error = await loadLeaderboard()
        case .providers:
            error = await loadProviders()
        }

        if let error {
            errorMessage = error
        } else if errorMessage?.hasPrefix(selectedTab.rawValue) == true {
            errorMessage = nil
        }
        lastRefresh = Date()
    }

    func refreshActiveSessionsOnly() async {
        if isLoadingActiveSessions { return }
        isLoadingActiveSessions = true
        defer { isLoadingActiveSessions = false }

        async let sessionsResult = api.fetchActiveSessions(config: config)
        async let overviewResult = api.fetchOverview(config: config)
        async let recentLogsResult = api.fetchLogs(
            config: config,
            page: 1,
            pageSize: 10,
            startDate: nil,
            model: "",
            statusCode: "",
            sessionId: ""
        )

        var errors: [String] = []

        do {
            activeSessions = try await sessionsResult
        } catch {
            errors.append("Sessions: \(error.localizedDescription)")
        }

        do {
            overview = try await overviewResult
        } catch {
            errors.append("Dashboard: \(error.localizedDescription)")
        }

        do {
            let page = try await recentLogsResult
            recentLogs = page.logs
        } catch {
            errors.append("Logs: \(error.localizedDescription)")
        }

        if !errors.isEmpty, activeSessions.isEmpty, recentLogs.isEmpty, errorMessage == nil {
            errorMessage = errors.joined(separator: " · ")
        }
    }

    func setProvider(_ provider: CCHProvider, enabled: Bool) async {
        actionMessage = nil
        do {
            try await api.setProviderEnabled(config: config, providerId: provider.id, enabled: enabled)
            actionMessage = enabled ? "渠道已启用" : "渠道已停用"
            _ = await loadProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetCircuit(_ provider: CCHProvider) async {
        actionMessage = nil
        do {
            try await api.resetProviderCircuit(config: config, providerId: provider.id)
            actionMessage = "熔断状态已重置"
            _ = await loadProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func probe(_ provider: CCHProvider) async {
        actionMessage = nil
        do {
            let result = try await api.probeFirstEndpoint(config: config, provider: provider)
            if result.ok {
                let latency = result.latencyMs.map { formatMillisecondsAsSeconds($0) } ?? "正常"
                actionMessage = "测速 \(provider.name): \(latency)"
            } else {
                actionMessage = "测速失败: \(result.errorMessage)"
            }
            _ = await loadProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openCCH(_ path: String = "/zh-CN/dashboard") {
        let base = cchBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + path) else { return }
        NSWorkspace.shared.open(url)
    }

    private func loadOverview() async -> String? {
        do {
            overview = try await api.fetchOverview(config: config)
            return nil
        } catch {
            return "总览: \(error.localizedDescription)"
        }
    }

    private func loadActiveSessions() async -> String? {
        do {
            activeSessions = try await api.fetchActiveSessions(config: config)
            return nil
        } catch {
            return "会话: \(error.localizedDescription)"
        }
    }

    private func loadLeaderboard() async -> String? {
        do {
            leaderboard = try await api.fetchLeaderboard(
                config: config,
                period: leaderboardPeriod.rawValue,
                scope: leaderboardScope.rawValue
            )
            return nil
        } catch {
            leaderboard = []
            return "排行: \(error.localizedDescription)"
        }
    }

    private func loadLogs() async -> String? {
        do {
            let page = try await api.fetchLogs(
                config: config,
                page: 1,
                pageSize: 50,
                startDate: logRange.startDate,
                model: logModelFilter,
                statusCode: logStatusFilter,
                sessionId: logSessionFilter
            )
            logs = page.logs
            if logModelFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               logStatusFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               logSessionFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recentLogs = page.logs
            }
            logTotal = page.total
            logSummary = page.summary
            if let selectedLog, !page.logs.contains(where: { $0.id == selectedLog.id }) {
                self.selectedLog = nil
            }
            return nil
        } catch {
            return "日志: \(error.localizedDescription)"
        }
    }

    private func loadProviders() async -> String? {
        do {
            providers = try await api.fetchProviders(config: config)
            selectedProviderGroups = selectedProviderGroups.intersection(Set(providerGroups))
            return nil
        } catch {
            return "渠道: \(error.localizedDescription)"
        }
    }

    private func observeSystemWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

}

private func isRunningStatus(_ status: String) -> Bool {
    let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.isEmpty { return false }
    return normalized.contains("active")
        || normalized.contains("running")
        || normalized.contains("progress")
        || normalized.contains("request")
        || normalized.contains("retry")
        || normalized.contains("请求")
}

private func menuBarActivityScore(_ session: CCHActiveSession) -> Int {
    if session.concurrentCount > 0 { return 300 }
    if session.status.lowercased().contains("retry") { return 200 }
    if isRunningStatus(session.status) { return 100 }
    return 0
}

func formatMoney(_ value: Double) -> String {
    if value >= 1000 {
        return String(format: "$%.1fk", value / 1000)
    }
    if value >= 100 {
        return String(format: "$%.0f", value)
    }
    return String(format: "$%.2f", value)
}

func compactNumber(_ value: Int) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", Double(value) / 1_000_000)
    }
    if value >= 1_000 {
        return String(format: "%.1fk", Double(value) / 1_000)
    }
    return "\(value)"
}

func formatPercent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

func formatLatency(_ value: Int) -> String {
    value <= 0 ? "-" : String(format: "%.1fs", Double(value) / 1000)
}

func formatMillisecondsAsSeconds(_ value: Int?) -> String {
    guard let value else { return "-" }
    return String(format: "%.2fs", Double(value) / 1000)
}

func formatTokensPerSecond(_ value: Double?) -> String {
    guard let value, value > 0 else { return "-- tok/s" }
    return String(format: "%.0f tok/s", value)
}

func computedTokensPerSecond(outputTokens: Int, durationMs: Int?, ttfbMs: Int?) -> Double? {
    guard
        outputTokens > 0,
        let durationMs,
        durationMs > 0
    else { return nil }
    let generationMs = max(1, durationMs - (ttfbMs ?? 0))
    return Double(outputTokens) / (Double(generationMs) / 1000)
}

func cacheHitRate(cacheReadTokens: Int, inputTokens: Int) -> Double {
    guard inputTokens > 0 else { return 0 }
    return min(1, max(0, Double(cacheReadTokens) / Double(inputTokens)))
}

func formatMultiplier(_ value: Double) -> String {
    if abs(value - 1) < 0.001 {
        return "x1"
    }
    if value.rounded() == value {
        return String(format: "x%.0f", value)
    }
    return String(format: "x%.2f", value)
}

func multiplierLevel(_ value: Double) -> Int {
    if value <= 0.5 { return 0 }
    if value <= 1.0 { return 1 }
    if value <= 2.0 { return 2 }
    return 3
}

func compactScrollingText(_ value: String, offset: Int, visibleCharacters: Int) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > visibleCharacters, visibleCharacters > 0 else {
        return trimmed
    }
    let tape = Array(trimmed + "    ")
    let start = offset % tape.count
    return String((0..<visibleCharacters).map { tape[(start + $0) % tape.count] })
}

func shortTime(_ raw: String) -> String {
    guard let date = parseCCHDate(raw) else {
        return raw
    }
    return date.formatted(date: .omitted, time: .shortened)
}

func providerGroupTitle(_ value: String) -> String {
    providerGroupTitles(value).first ?? "默认"
}

func providerGroupTitles(_ value: String) -> [String] {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return ["默认"] }
    let groups = trimmed
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return groups.isEmpty ? ["默认"] : groups
}

func parseCCHDate(_ raw: String) -> Date? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: trimmed) {
        return date
    }

    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: trimmed) {
        return date
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: trimmed)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    if total < 60 {
        return "\(total)s"
    }
    let minutes = total / 60
    let seconds = total % 60
    if minutes < 60 {
        return "\(minutes)m\(String(format: "%02d", seconds))s"
    }
    let hours = minutes / 60
    return "\(hours)h\(String(format: "%02d", minutes % 60))m"
}

func compactProviderName(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Provider" : trimmed
}
