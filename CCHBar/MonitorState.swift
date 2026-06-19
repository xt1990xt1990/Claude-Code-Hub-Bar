import AppKit
import Combine
import SwiftUI

enum CCHPanelTab: String, CaseIterable, Identifiable {
    case dashboard = "总览"
    case leaderboard = "排行"
    case logs = "日志"
    case providers = "渠道"
    case upstreamRates = "上游倍率"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .leaderboard: return "chart.bar.xaxis"
        case .logs: return "list.bullet.rectangle"
        case .providers: return "server.rack"
        case .upstreamRates: return "arrow.triangle.2.circlepath"
        }
    }
}

enum CCHLeaderboardPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case allTime

    var id: String { rawValue }
    var title: String {
        switch self {
        case .daily: return "今天"
        case .weekly: return "本周"
        case .monthly: return "本月"
        case .allTime: return "全部"
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

    var id: String { rawValue }
    var title: String { "1h" }

    var startDate: Date? {
        Calendar.current.date(byAdding: .hour, value: -1, to: Date())
    }
}

struct CCHAvailableUpdate: Equatable {
    let version: String
    let displayName: String
    let releaseURL: URL
    let body: String
    let publishedAt: Date?
}

private enum CCHLogHighlightContext {
    case recent
    case logsPage
}

private enum CCHRefreshKey: Hashable {
    case overview
    case activeSessions
    case recentLogs
    case logs(includeStats: Bool)
    case leaderboard
    case providers(usage: Bool)
}

private struct CCHRefreshTaskSlot {
    let id: UUID
    let task: Task<String?, Never>
}

private struct UpstreamRateHostRefreshResult {
    let host: String
    let snapshot: UpstreamRateSnapshot?
    let credential: UpstreamRateCredential?
    let errorMessage: String?
}

private enum CCHRetentionLimits {
    static let recentLogHistory = 240
    static let knownLogIds = 1_200
    static let parsedDateCache = 1_500
}

private enum CCHProviderModelTestLimits {
    static let maxCustomModels = 8
    static let storageKey = "provider_custom_test_models_v1"
}

private enum CCHUpstreamRateStorage {
    static let selectedProviderIdsKey = "upstream_rate_selected_provider_ids_v1"
    static let ignoredHostsKey = "upstream_rate_ignored_hosts_v1"
    static let sourceTypeOverridesKey = "upstream_rate_source_type_overrides_v1"
    static let hostDisplayNamesKey = "upstream_rate_host_display_names_v1"
    static let snapshotsKey = "upstream_rate_snapshots_v1"
    static let balanceRefreshInterval: TimeInterval = 60 * 60
    static let balanceStaleInterval: TimeInterval = 60 * 60
    static let minAutoSyncIntervalHours = 1.0
    static let maxAutoSyncIntervalHours = 72.0
}

@MainActor
final class MonitorState: ObservableObject {
    @AppStorage("cch_base_url") var cchBaseURL = ""
    @AppStorage("cch_token") var cchToken = ""
    @AppStorage("cch_env_path") var cchEnvPath = ""
    @AppStorage("refreshInterval") var refreshInterval: Double = 15
    @AppStorage("active_session_user_filter") var activeSessionUserFilter = ""
    @AppStorage("show_status_bar_details") var showStatusBarDetails = true
    @AppStorage("check_for_updates") var checkForUpdatesEnabled: Bool = true
    @AppStorage("upstream_rate_auto_sync_enabled") var upstreamRateAutoSyncEnabled = false
    @AppStorage("upstream_rate_auto_sync_interval_hours") var upstreamRateAutoSyncIntervalHours = 6.0
    @AppStorage("dismissed_update_version") var dismissedUpdateVersion: String = ""
    @AppStorage("cch_theme") private var themeRawValue = CCHTheme.liquidGlass.rawValue

    @Published var selectedTab: CCHPanelTab = .dashboard
    @Published var leaderboardPeriod: CCHLeaderboardPeriod = .daily
    @Published var leaderboardScope: CCHLeaderboardScope = .user
    @Published var expandedLeaderboardEntryId: String?
    @Published var logRange: CCHLogRange = .hour1
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
    @Published var logPage = 1
    @Published var isLoadingMoreLogs = false
    @Published var providers: [CCHProvider] = []
    @Published private(set) var assignableProviderGroups: [CCHProviderGroup] = []
    @Published private var providerGroupAssignmentOverrides: [Int: Set<String>] = [:]
    @Published private(set) var highlightedLogIds: Set<Int> = []
    @Published private(set) var modelTestingProviderIds: Set<Int> = []
    @Published private(set) var providerModelTestResults: [Int: CCHProviderModelTestResult] = [:]
    @Published private(set) var providerModelTestResultsByModel: [Int: [String: CCHProviderModelTestResult]] = [:]
    @Published private(set) var providerModelTestProgress: [Int: CCHProviderModelTestProgress] = [:]
    @Published private(set) var providerCustomTestModels: [Int: [String]] = [:]
    @Published private(set) var providerMultiplierUpdatingIds: Set<Int> = []
    @Published private(set) var upstreamRateSelectedProviderIds: Set<Int> = []
    @Published private(set) var upstreamRateIgnoredHosts: Set<String> = []
    @Published private(set) var upstreamRateSourceTypeOverrides: [String: UpstreamRateSourceType] = [:]
    @Published private(set) var upstreamRateHostDisplayNames: [String: String] = [:]
    @Published private(set) var upstreamRateSnapshots: [UpstreamRateSnapshot] = []
    @Published private(set) var upstreamRateLastCheckedAt: Date?
    @Published private(set) var upstreamRateCredentials: [UpstreamRateCredential] = []
    @Published private(set) var upstreamRateFetchingHosts: Set<String> = []
    @Published private(set) var isRefreshingUpstreamRates = false
    @Published private(set) var isRefreshingUpstreamBalances = false
    @Published private(set) var upstreamBalanceLastRefreshedAt: Date?

    @Published var lastRefresh: Date?
    @Published var isLoading = false
    @Published var actionMessage: String?
    @Published var actionMessageIsWarning = false
    @Published var errorMessage: String?
    @Published var panelVisible = false
    @Published private(set) var cacheStatusByLogId: [Int: CCHCacheStatusContext] = [:]
    @Published private(set) var menuBarCacheAlertLogId: Int?
    @Published private(set) var simulatedCacheAlertLogId: Int?
    @Published private(set) var simulatedIdleCacheAlert = false
    @Published private(set) var availableUpdate: CCHAvailableUpdate?
    @Published private(set) var lastUpdateCheck: Date?
    @Published private(set) var updateCheckError: String?
    @Published private(set) var isCheckingForUpdate = false
    @Published private(set) var leaderboardSummary = CCHLeaderboardSummary()
    @Published private(set) var providerFilterSnapshot = CCHProviderFilterSnapshot()
    @Published private(set) var statusBarSnapshot = CCHStatusBarSnapshot(
        showsDetails: true,
        idlePrimary: "TTL $0.00",
        idleDetail: "0 req",
        idleCacheState: .normal,
        runningItems: [],
        hasRecentLogs: false,
        generatedAt: Date()
    )

    private let api = APIService()
    private let upstreamRateService = UpstreamRateService()
    private let upstreamCredentialStore = UpstreamRateCredentialStore()
    private var refreshTimer: AnyCancellable?
    private var activeSessionTimer: AnyCancellable?
    private var focusedViewTimer: AnyCancellable?
    private var updateCheckTimer: AnyCancellable?
    private var upstreamRateAutoSyncTimer: AnyCancellable?
    private var upstreamBalanceRefreshTimer: AnyCancellable?
    private var wakeObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var isLoadingActiveSessions = false
    private var isLoadingStatusBarData = false
    private var isLoadingFocusedView = false
    private let statusBarPollingPolicy = CCHStatusBarPollingPolicy()
    private var lastAnnouncedCacheAlertLogId: Int?
    private var cacheAlertDismissTask: Task<Void, Never>?
    private var simulatedCacheAlertDismissTask: Task<Void, Never>?
    private var actionMessageDismissTask: Task<Void, Never>?
    private var highlightedLogDismissTasks: [Int: Task<Void, Never>] = [:]
    private var knownRecentLogIds = Set<Int>()
    private var knownRecentLogIdOrder: [Int] = []
    private var knownLogPageIds = Set<Int>()
    private var knownLogPageIdOrder: [Int] = []
    private var recentLogHistory: [CCHLogEntry] = []
    private var providerMultiplierByName: [String: Double] = [:]
    private var providerMultiplierByProviderId: [Int: Double] = [:]
    private var cachedMenuBarRunningLogs: [CCHLogEntry] = []
    private var refreshTasks: [CCHRefreshKey: CCHRefreshTaskSlot] = [:]
    private var lastProviderUsageRefresh: Date?
    private var lastProviderGroupsRefresh: Date?
    private var lastLogSummaryRefresh: Date?
    private var lastStatusBarDataRefresh: Date?
    private var lastStatusBarOverviewRefresh: Date?
    private var lastStatusBarRunningSeenAt: Date?
    private var officialProviderGroups: [CCHProviderGroup] = []

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var config: CCHConfig {
        CCHConfig(baseURL: cchBaseURL, token: cchToken, envPath: cchEnvPath)
    }

    var selectedTheme: CCHTheme {
        get { CCHTheme(rawValue: themeRawValue) ?? .liquidGlass }
        set {
            guard themeRawValue != newValue.rawValue else { return }
            themeRawValue = newValue.rawValue
            objectWillChange.send()
        }
    }

    var menuBarText: String {
        "TTL \(formatStatusBarMoney(overview.todayCost))"
    }

    var menuBarIdleDetail: String {
        "\(compactNumber(overview.todayRequests)) req"
    }

    var hasCacheAlert: Bool {
        menuBarCacheAlertLogId != nil || simulatedCacheAlertLogId != nil || simulatedIdleCacheAlert
    }

    var statusBarCacheState: CCHCacheVisibilityState {
        hasCacheAlert ? .rebuilding : .normal
    }

    var providerMultiplierById: [Int: Double] {
        providerMultiplierByProviderId
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
        cachedMenuBarRunningLogs
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
        providerFilterSnapshot.groups
    }

    var filteredProviders: [CCHProvider] {
        providerFilterSnapshot.providers
    }

    var filteredEnabledProviderCount: Int {
        providerFilterSnapshot.enabledCount
    }

    var filteredUnhealthyProviderCount: Int {
        providerFilterSnapshot.unhealthyCount
    }

    var upstreamRateSites: [UpstreamRateSite] {
        UpstreamRateMatcher.buildSites(
            providers: providers.map(upstreamProviderInput),
            snapshots: upstreamRateSnapshots,
            selectedProviderIds: upstreamRateSelectedProviderIds,
            ignoredHosts: upstreamRateIgnoredHosts,
            displayNames: upstreamRateHostDisplayNames
        )
    }

    var upstreamRateSyncableSites: [UpstreamRateSite] {
        upstreamRateSites.filter { $0.section == .syncable }
    }

    var upstreamRateNeedsConfigurationSites: [UpstreamRateSite] {
        upstreamRateSites.filter { $0.section == .needsConfiguration }
    }

    var upstreamRateUnsupportedSites: [UpstreamRateSite] {
        upstreamRateSites.filter { $0.section == .unsupported }
    }

    var upstreamRateCheckedSyncCount: Int {
        upstreamRateSites.flatMap(\.syncableRows).count
    }

    var upstreamRatePendingSyncCount: Int {
        upstreamRateSites.reduce(0) { $0 + $1.pendingSyncCount }
    }

    func leaderboardCacheHitRate(for entry: CCHLeaderboardEntry) -> Double? {
        entry.cacheHitRate
    }

    var leaderboardOfficialCacheHitRate: Double? {
        leaderboardSummary.cacheHitRate
    }

    func setLeaderboardScope(_ scope: CCHLeaderboardScope) {
        leaderboardScope = scope
        expandedLeaderboardEntryId = nil
    }

    init() {
        providerCustomTestModels = Self.loadProviderCustomTestModels()
        upstreamRateSelectedProviderIds = Self.loadIntSet(key: CCHUpstreamRateStorage.selectedProviderIdsKey)
        upstreamRateIgnoredHosts = Self.loadStringSet(key: CCHUpstreamRateStorage.ignoredHostsKey)
        upstreamRateSourceTypeOverrides = Self.loadUpstreamRateSourceTypeOverrides()
        upstreamRateHostDisplayNames = Self.loadUpstreamRateHostDisplayNames()
        upstreamRateSnapshots = Self.loadUpstreamRateSnapshots()
        upstreamRateCredentials = upstreamCredentialStore.load()
        startRefreshTimer()
        startActiveSessionTimer()
        startUpdateCheckTimer()
        startUpstreamRateAutoSyncTimer()
        startUpstreamBalanceRefreshTimer()
        observeSystemWake()
        refreshTask = Task { await refresh() }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await self?.checkForUpdates(force: false)
        }
    }

    deinit {
        refreshTimer?.cancel()
        activeSessionTimer?.cancel()
        focusedViewTimer?.cancel()
        updateCheckTimer?.cancel()
        upstreamRateAutoSyncTimer?.cancel()
        upstreamBalanceRefreshTimer?.cancel()
        refreshTask?.cancel()
        cacheAlertDismissTask?.cancel()
        simulatedCacheAlertDismissTask?.cancel()
        actionMessageDismissTask?.cancel()
        highlightedLogDismissTasks.values.forEach { $0.cancel() }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func cacheStatus(for log: CCHLogEntry) -> CCHCacheStatusContext {
        if isCacheAlertLog(log.id) {
            return CCHCacheStatusContext(
                state: .rebuilding,
                createdTokens: log.cacheCreationTokens,
                readTokens: log.cacheReadTokens
            )
        }
        return cacheStatusByLogId[log.id] ?? CCHCacheStatusContext(
            state: .normal,
            createdTokens: log.cacheCreationTokens,
            readTokens: log.cacheReadTokens
        )
    }

    func isCacheAlertLog(_ logId: Int) -> Bool {
        menuBarCacheAlertLogId == logId || simulatedCacheAlertLogId == logId
    }

    func simulateCacheAlert() {
        simulatedCacheAlertDismissTask?.cancel()

        if let log = (menuBarRunningLogs.first ?? recentLogs.first ?? logs.first) {
            simulatedCacheAlertLogId = log.id
            simulatedIdleCacheAlert = false
        } else {
            simulatedCacheAlertLogId = nil
            simulatedIdleCacheAlert = true
        }
        updateStatusBarSnapshot()

        actionMessage = "已触发缓存提醒预览"
        actionMessageIsWarning = false
        simulatedCacheAlertDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self.simulatedCacheAlertLogId = nil
            self.simulatedIdleCacheAlert = false
            self.updateStatusBarSnapshot()
            if self.actionMessage == "已触发缓存提醒预览" {
                self.actionMessage = nil
                self.actionMessageIsWarning = false
            }
        }
    }

    func providerMultiplier(for providerName: String) -> Double {
        let normalized = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return 1 }
        return providerMultiplierByName[normalized.lowercased()] ?? 1
    }

    func isProviderGroupSelected(_ group: String) -> Bool {
        group == "全部" ? selectedProviderGroups.isEmpty : selectedProviderGroups.contains(group)
    }

    func toggleProviderGroup(_ group: String) {
        guard group != "全部" else {
            selectedProviderGroups = []
            rebuildProviderFilterSnapshot()
            return
        }

        var next = selectedProviderGroups
        if next.contains(group) {
            next.remove(group)
        } else {
            next.insert(group)
        }
        selectedProviderGroups = next
        rebuildProviderFilterSnapshot()
    }

    func assignedGroupNames(for provider: CCHProvider) -> Set<String> {
        providerGroupAssignmentOverrides[provider.id] ?? storedGroupNames(for: provider)
    }

    func displayGroupTitles(for provider: CCHProvider) -> [String] {
        let groups = assignedGroupNames(for: provider)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return groups.isEmpty ? ["默认"] : groups
    }

    func toggleProviderGroupAssignment(_ group: CCHProviderGroup, for provider: CCHProvider) async {
        let groupName = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !groupName.isEmpty, !isDefaultProviderGroup(groupName) else { return }

        actionMessageDismissTask?.cancel()
        actionMessage = nil
        actionMessageIsWarning = false

        var nextGroups = assignedGroupNames(for: provider)
        let didRemove = nextGroups.contains(groupName)
        if didRemove {
            nextGroups.remove(groupName)
        } else {
            nextGroups.insert(groupName)
        }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            providerGroupAssignmentOverrides[provider.id] = nextGroups
            let allGroups = computedProviderGroups()
            selectedProviderGroups = selectedProviderGroups.intersection(Set(allGroups))
            rebuildProviderFilterSnapshot(groups: allGroups)
        }

        do {
            try await api.setProviderGroups(
                config: config,
                providerId: provider.id,
                groupTag: providerGroupTag(from: nextGroups)
            )
            flashActionMessage(didRemove ? "已移出分组 \(groupName)" : "已加入分组 \(groupName)")
            _ = await loadProviders()
        } catch {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                providerGroupAssignmentOverrides[provider.id] = storedGroupNames(for: provider)
                rebuildProviderFilterSnapshot()
            }
            flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
        }
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
        activeSessionTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshStatusBarDataOnly() }
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

    func refreshStatusBarSnapshotForPreferencesChange() {
        updateStatusBarSnapshot()
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

        async let overviewResult = runRefresh(.overview) { await self.loadOverview() }
        async let sessionsResult = runRefresh(.activeSessions) { await self.loadActiveSessions() }
        async let leaderboardResult = runRefresh(.leaderboard) { await self.loadLeaderboard() }
        async let logsResult = runRefresh(.logs(includeStats: true)) { await self.loadLogs(includeStats: true) }
        async let providersResult = runRefresh(.providers(usage: true)) { await self.loadProviders(includeUsage: true) }

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
            runRefresh(.overview) { await self.loadOverview() },
            runRefresh(.providers(usage: false)) { await self.loadProviders(includeUsage: self.shouldRefreshProviderUsage()) }
        ].compactMap { $0 }

        if !errors.isEmpty {
            errorMessage = errors.joined(separator: " · ")
        }
        lastRefresh = Date()
    }

    func refreshLogsOnly() async {
        isLoading = true
        errorMessage = await runRefresh(.logs(includeStats: true)) {
            await self.loadLogs(reset: true, includeStats: true)
        }
        lastRefresh = Date()
        isLoading = false
    }

    func loadMoreLogs() async {
        guard !isLoadingMoreLogs, logs.count < logTotal || logTotal == 0 else { return }
        isLoadingMoreLogs = true
        errorMessage = await runRefresh(.logs(includeStats: false)) {
            await self.loadLogs(reset: false, includeStats: false)
        }
        lastRefresh = Date()
        isLoadingMoreLogs = false
    }

    func refreshLeaderboardOnly() async {
        isLoading = true
        errorMessage = await runRefresh(.leaderboard) { await self.loadLeaderboard() }
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
            async let overviewError = runRefresh(.overview) { await self.loadOverview() }
            async let recentError = runRefresh(.recentLogs) { await self.loadRecentLogsForStatusBar() }
            error = await [overviewError, recentError].compactMap { $0 }.first
        case .logs:
            error = await runRefresh(.logs(includeStats: shouldRefreshLogSummary())) {
                await self.loadLogs(reset: true, includeStats: self.shouldRefreshLogSummary())
            }
        case .leaderboard:
            error = await runRefresh(.leaderboard) { await self.loadLeaderboard() }
        case .providers:
            error = await runRefresh(.providers(usage: true)) { await self.loadProviders(includeUsage: true) }
        case .upstreamRates:
            error = await runRefresh(.providers(usage: true)) { await self.loadProviders(includeUsage: true) }
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

        async let sessionsError = runRefresh(.activeSessions) { await self.loadActiveSessions() }
        async let overviewError = runRefresh(.overview) { await self.loadOverview() }
        async let recentLogsError = runRefresh(.recentLogs) { await self.loadRecentLogsForStatusBar() }

        let errors = await [sessionsError, overviewError, recentLogsError].compactMap { $0 }

        if !errors.isEmpty, activeSessions.isEmpty, recentLogs.isEmpty, errorMessage == nil {
            errorMessage = errors.joined(separator: " · ")
        }
    }

    func refreshStatusBarDataOnly() async {
        if isLoadingStatusBarData { return }
        let now = Date()
        guard shouldRefreshStatusBarData(now: now) else { return }
        isLoadingStatusBarData = true
        defer { isLoadingStatusBarData = false }

        var errors: [String] = []
        let shouldRefreshOverview = shouldRefreshStatusBarOverview(now: now)

        if let recentLogsError = await runRefresh(.recentLogs, operation: { await self.loadRecentLogsForStatusBar() }) {
            errors.append(recentLogsError)
        }
        lastStatusBarDataRefresh = now

        if shouldRefreshOverview {
            if let overviewError = await runRefresh(.overview, operation: { await self.loadOverview() }) {
                errors.append(overviewError)
            }
            lastStatusBarOverviewRefresh = now
        }

        if !errors.isEmpty, recentLogs.isEmpty, errorMessage == nil {
            errorMessage = errors.joined(separator: " · ")
        }
    }

    func setProvider(_ provider: CCHProvider, enabled: Bool) async {
        actionMessageDismissTask?.cancel()
        actionMessage = nil
        actionMessageIsWarning = false
        do {
            try await api.setProviderEnabled(config: config, providerId: provider.id, enabled: enabled)
            flashActionMessage(enabled ? "渠道已启用" : "渠道已停用")
            _ = await loadProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetCircuit(_ provider: CCHProvider) async {
        actionMessageDismissTask?.cancel()
        actionMessage = nil
        actionMessageIsWarning = false
        do {
            try await api.resetProviderCircuit(config: config, providerId: provider.id)
            flashActionMessage("熔断状态已重置")
            _ = await loadProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func probe(_ provider: CCHProvider) async {
        actionMessageDismissTask?.cancel()
        actionMessage = nil
        actionMessageIsWarning = false
        do {
            let result = try await api.probeFirstEndpoint(config: config, provider: provider)
            if result.ok {
                let latency = formatProbeLatency(result.latencyMs)
                let method = result.method.trimmingCharacters(in: .whitespacesAndNewlines)
                let suffix = method.isEmpty ? "" : " · \(method)"
                flashActionMessage("测速 \(provider.name): \(latency)\(suffix)")
            } else {
                flashActionMessage(result.errorMessage, duration: 5, isWarning: true)
            }
        } catch {
            flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
        }
    }

    func isProviderModelTesting(_ provider: CCHProvider) -> Bool {
        modelTestingProviderIds.contains(provider.id)
    }

    func providerModelTestResult(for provider: CCHProvider) -> CCHProviderModelTestResult? {
        providerModelTestResults[provider.id]
    }

    func providerModelTestResults(for provider: CCHProvider) -> [String: CCHProviderModelTestResult] {
        providerModelTestResultsByModel[provider.id] ?? [:]
    }

    func providerModelTestProgress(for provider: CCHProvider) -> CCHProviderModelTestProgress? {
        providerModelTestProgress[provider.id]
    }

    func customTestModels(for provider: CCHProvider) -> [String] {
        providerCustomTestModels[provider.id] ?? []
    }

    func addCustomTestModel(_ model: String, for provider: CCHProvider) {
        let normalized = normalizedProviderTestModel(model)
        guard !normalized.isEmpty else {
            flashActionMessage("模型名称不能为空", duration: 3, isWarning: true)
            return
        }

        var models = providerCustomTestModels[provider.id] ?? []
        models = normalizedProviderTestModels(models + [normalized])
        if models.count > CCHProviderModelTestLimits.maxCustomModels {
            models = Array(models.prefix(CCHProviderModelTestLimits.maxCustomModels))
            flashActionMessage("最多保存 \(CCHProviderModelTestLimits.maxCustomModels) 个测试模型", duration: 4, isWarning: true)
        } else {
            flashActionMessage("已添加测试模型 \(normalized)")
        }
        providerCustomTestModels[provider.id] = models
        saveProviderCustomTestModels()
    }

    func removeCustomTestModel(_ model: String, for provider: CCHProvider) {
        let normalized = normalizedProviderTestModel(model)
        var models = providerCustomTestModels[provider.id] ?? []
        models.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        providerCustomTestModels[provider.id] = models
        if models.isEmpty {
            providerModelTestResultsByModel[provider.id] = nil
        } else {
            providerModelTestResultsByModel[provider.id]?.removeValue(forKey: normalized)
        }
        saveProviderCustomTestModels()
    }

    func isProviderMultiplierUpdating(_ provider: CCHProvider) -> Bool {
        providerMultiplierUpdatingIds.contains(provider.id)
    }

    func isUpstreamRateProviderUpdating(_ providerId: Int) -> Bool {
        providerMultiplierUpdatingIds.contains(providerId)
    }

    func provider(forUpstreamRateRow row: UpstreamRateProviderRow) -> CCHProvider? {
        providers.first { $0.id == row.providerId }
    }

    func toggleUpstreamRateSyncSelection(_ row: UpstreamRateProviderRow) async {
        guard row.matchStatus == .matched else { return }
        if upstreamRateSelectedProviderIds.contains(row.providerId) {
            upstreamRateSelectedProviderIds.remove(row.providerId)
        } else {
            upstreamRateSelectedProviderIds.insert(row.providerId)
            saveUpstreamRateSelectedProviderIds()
            if row.hasRateChange {
                await syncUpstreamRate(row, showNoopMessage: false)
            }
            return
        }
        saveUpstreamRateSelectedProviderIds()
    }

    func refreshUpstreamRates(silent: Bool = false) async {
        if isRefreshingUpstreamRates { return }
        isRefreshingUpstreamRates = true
        defer { isRefreshingUpstreamRates = false }

        if providers.isEmpty {
            _ = await loadProviders(includeUsage: true)
        }

        let credentialsByHost = Dictionary(uniqueKeysWithValues: upstreamRateCredentials.map { ($0.host, $0) })
        let grouped = Dictionary(grouping: providers.map(upstreamProviderInput)) { input in
            UpstreamRateMatcher.providerHost(input) ?? "unknown-\(input.id)"
        }
        let sortedGroups = grouped.sorted { $0.key < $1.key }
        let currentConfig = config

        upstreamRateFetchingHosts = Set(sortedGroups.map(\.key))
        defer { upstreamRateFetchingHosts.removeAll() }

        let results = await withTaskGroup(of: UpstreamRateHostRefreshResult.self) { group in
            for (host, values) in sortedGroups {
                let credential = credentialsByHost[host]
                let localType = localDetectedSourceType(host: host)
                group.addTask { [api, upstreamRateService] in
                    await Self.refreshUpstreamRateHost(
                        host: host,
                        values: values,
                        credential: credential,
                        localType: localType,
                        config: currentConfig,
                        api: api,
                        upstreamRateService: upstreamRateService
                    )
                }
            }

            var values: [UpstreamRateHostRefreshResult] = []
            for await result in group {
                values.append(result)
            }
            return values.sorted { $0.host < $1.host }
        }

        var nextSnapshots: [UpstreamRateSnapshot] = []
        var nextCredentials = upstreamRateCredentials
        for result in results {
            if let snapshot = result.snapshot {
                nextSnapshots.append(snapshot)
            }
            if let credential = result.credential {
                nextCredentials.removeAll { $0.host == credential.host }
                nextCredentials.append(credential)
            }
            if let errorMessage = result.errorMessage, !silent {
                flashActionMessage("\(result.host): \(errorMessage)", duration: 5, isWarning: true)
            }
        }
        upstreamRateCredentials = nextCredentials.sorted { $0.host < $1.host }

        do {
            try upstreamCredentialStore.save(upstreamRateCredentials)
        } catch {
            flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
        }
        let activeHosts = Set(sortedGroups.map(\.key))
        upstreamRateSnapshots = UpstreamRateSnapshot
            .mergeLatest(cached: upstreamRateSnapshots, refreshed: nextSnapshots)
            .filter { activeHosts.contains($0.host) }
        saveUpstreamRateSnapshots()
        upstreamRateLastCheckedAt = Date()
        await syncSelectedUpstreamRates(showEmptyMessage: false)
        if !silent {
            flashActionMessage("上游倍率已检测")
        }
    }

    func refreshUpstreamBalances(silent: Bool = false, onlyIfStale: Bool = false) async {
        if isRefreshingUpstreamBalances { return }
        if onlyIfStale,
           let upstreamBalanceLastRefreshedAt,
           Date().timeIntervalSince(upstreamBalanceLastRefreshedAt) < CCHUpstreamRateStorage.balanceStaleInterval {
            return
        }
        let credentials = upstreamRateCredentials.filter { credential in
            credential.sourceType == .sub2API || credential.sourceType == .newAPI
        }
        guard !credentials.isEmpty else { return }

        isRefreshingUpstreamBalances = true
        defer { isRefreshingUpstreamBalances = false }

        let results = await withTaskGroup(of: UpstreamRateHostRefreshResult.self) { group in
            for credential in credentials {
                group.addTask { [upstreamRateService] in
                    do {
                        let outcome = try await upstreamRateService.fetchBalance(credential: credential)
                        return UpstreamRateHostRefreshResult(
                            host: credential.host,
                            snapshot: outcome.snapshot,
                            credential: outcome.credential,
                            errorMessage: nil
                        )
                    } catch {
                        return UpstreamRateHostRefreshResult(
                            host: credential.host,
                            snapshot: nil,
                            credential: nil,
                            errorMessage: error.localizedDescription
                        )
                    }
                }
            }

            var values: [UpstreamRateHostRefreshResult] = []
            for await result in group {
                values.append(result)
            }
            return values.sorted { $0.host < $1.host }
        }

        var balanceSnapshots: [UpstreamRateSnapshot] = []
        var nextCredentials = upstreamRateCredentials
        for result in results {
            if let snapshot = result.snapshot, snapshot.balance != nil {
                balanceSnapshots.append(snapshot)
            }
            if let credential = result.credential {
                nextCredentials.removeAll { $0.host == credential.host }
                nextCredentials.append(credential)
            }
            if let errorMessage = result.errorMessage, !silent {
                flashActionMessage("\(result.host): \(errorMessage)", duration: 5, isWarning: true)
            }
        }

        upstreamRateCredentials = nextCredentials.sorted { $0.host < $1.host }
        do {
            try upstreamCredentialStore.save(upstreamRateCredentials)
        } catch {
            flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
        }
        if !balanceSnapshots.isEmpty {
            upstreamRateSnapshots = UpstreamRateSnapshot.mergeBalances(
                cached: upstreamRateSnapshots,
                balances: balanceSnapshots
            )
            saveUpstreamRateSnapshots()
        }
        upstreamBalanceLastRefreshedAt = Date()
        if !silent {
            flashActionMessage(balanceSnapshots.isEmpty ? "未读取到上游余额" : "上游余额已刷新", isWarning: balanceSnapshots.isEmpty)
        }
    }

    nonisolated private static func refreshUpstreamRateHost(
        host: String,
        values: [UpstreamRateProviderInput],
        credential: UpstreamRateCredential?,
        localType: UpstreamRateSourceType,
        config: CCHConfig,
        api: APIService,
        upstreamRateService: UpstreamRateService
    ) async -> UpstreamRateHostRefreshResult {
        if let credential {
            do {
                let targets = await upstreamRateTargets(for: values, config: config, api: api)
                let outcome = try await upstreamRateService.fetchSnapshot(credential: credential, targets: targets)
                return UpstreamRateHostRefreshResult(host: host, snapshot: outcome.snapshot, credential: outcome.credential, errorMessage: nil)
            } catch {
                return UpstreamRateHostRefreshResult(
                    host: host,
                    snapshot: UpstreamRateSnapshot(host: host, sourceType: credential.sourceType, status: .needsLogin),
                    credential: nil,
                    errorMessage: error.localizedDescription
                )
            }
        }

        if localType != .unknown {
            return UpstreamRateHostRefreshResult(
                host: host,
                snapshot: UpstreamRateSnapshot(host: host, sourceType: localType, status: .needsLogin),
                credential: nil,
                errorMessage: nil
            )
        }

        let detected = await upstreamRateService.detectSite(baseURL: "https://\(host)", host: host)
        let snapshot = detected == .unknown ? nil : UpstreamRateSnapshot(host: host, sourceType: detected, status: .needsLogin)
        return UpstreamRateHostRefreshResult(host: host, snapshot: snapshot, credential: nil, errorMessage: nil)
    }

    nonisolated private static func upstreamRateTargets(
        for providers: [UpstreamRateProviderInput],
        config: CCHConfig,
        api: APIService
    ) async -> [UpstreamRateTarget] {
        await withTaskGroup(of: UpstreamRateTarget?.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let key = try await api.revealProviderKey(config: config, providerId: provider.id)
                        return UpstreamRateTarget(providerId: provider.id, providerName: provider.name, apiKey: key)
                    } catch {
                        return nil
                    }
                }
            }

            var targets: [UpstreamRateTarget] = []
            for await target in group {
                if let target {
                    targets.append(target)
                }
            }
            return targets.sorted { $0.providerId < $1.providerId }
        }
    }

    @discardableResult
    func saveUpstreamCredential(_ credential: UpstreamRateCredential) -> Bool {
        if upsertUpstreamCredential(credential, persist: true) {
            Task { await refreshUpstreamRates() }
            return true
        }
        return false
    }

    func draftUpstreamCredential(for site: UpstreamRateSite) -> UpstreamRateCredential {
        upstreamRateCredentials.first { $0.host == site.host } ?? .empty(host: site.host, sourceType: site.sourceType)
    }

    func setUpstreamRateSourceType(host: String, sourceType: UpstreamRateSourceType) {
        guard sourceType != .unknown else { return }
        let normalizedHost = normalizedUpstreamHost(host) ?? host.lowercased()
        upstreamRateSourceTypeOverrides[normalizedHost] = sourceType
        saveUpstreamRateSourceTypeOverrides()
        upsertLocalUpstreamRateSnapshot(host: normalizedHost, sourceType: sourceType, status: .needsLogin)
        flashActionMessage("已将 \(normalizedHost) 设为 \(sourceType.title)")
    }

    func setUpstreamRateHostDisplayName(host: String, displayName: String) {
        let normalizedHost = normalizedUpstreamHost(host) ?? host.lowercased()
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == normalizedHost {
            upstreamRateHostDisplayNames.removeValue(forKey: normalizedHost)
            flashActionMessage("已恢复 \(normalizedHost) 的官网名")
        } else {
            upstreamRateHostDisplayNames[normalizedHost] = trimmed
            flashActionMessage("已重命名为 \(trimmed)")
        }
        saveUpstreamRateHostDisplayNames()
    }

    func deleteUpstreamRateSite(_ site: UpstreamRateSite) {
        let normalizedHost = normalizedUpstreamHost(site.host) ?? site.host.lowercased()
        upstreamRateIgnoredHosts.insert(normalizedHost)
        upstreamRateSelectedProviderIds.subtract(site.rows.map(\.providerId))
        upstreamRateSnapshots.removeAll { $0.host == normalizedHost }
        upstreamRateCredentials.removeAll { $0.host == normalizedHost }
        upstreamRateSourceTypeOverrides.removeValue(forKey: normalizedHost)
        upstreamRateHostDisplayNames.removeValue(forKey: normalizedHost)
        saveUpstreamRateIgnoredHosts()
        saveUpstreamRateSelectedProviderIds()
        saveUpstreamRateSnapshots()
        saveUpstreamRateSourceTypeOverrides()
        saveUpstreamRateHostDisplayNames()
        do {
            try upstreamCredentialStore.save(upstreamRateCredentials)
        } catch {
            flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
            return
        }
        flashActionMessage("已从上游倍率移除 \(site.displayName)")
    }

    func syncSelectedUpstreamRates(showEmptyMessage: Bool = true) async {
        let rows = upstreamRateSites.flatMap(\.syncableRows).filter(\.hasRateChange)
        guard !rows.isEmpty else {
            if showEmptyMessage {
                flashActionMessage("没有需要应用的上游倍率")
            }
            return
        }

        for row in rows {
            await syncUpstreamRate(row, showNoopMessage: showEmptyMessage)
        }
    }

    func syncUpstreamRate(_ row: UpstreamRateProviderRow, showNoopMessage: Bool = true) async {
        guard let provider = providers.first(where: { $0.id == row.providerId }), let upstreamRate = row.upstreamRate else {
            if showNoopMessage {
                flashActionMessage("未找到可应用的上游倍率", duration: 4, isWarning: true)
            }
            return
        }
        guard row.matchStatus == .matched else {
            if showNoopMessage {
                flashActionMessage("该渠道尚未匹配上游 key", duration: 4, isWarning: true)
            }
            return
        }
        await updateProviderMultiplier(provider, multiplier: upstreamRate)
    }

    func startUpstreamRateAutoSyncTimer() {
        upstreamRateAutoSyncTimer?.cancel()
        guard upstreamRateAutoSyncEnabled else {
            upstreamRateAutoSyncTimer = nil
            return
        }
        let hours = min(
            max(upstreamRateAutoSyncIntervalHours, CCHUpstreamRateStorage.minAutoSyncIntervalHours),
            CCHUpstreamRateStorage.maxAutoSyncIntervalHours
        )
        if hours != upstreamRateAutoSyncIntervalHours {
            upstreamRateAutoSyncIntervalHours = hours
        }
        upstreamRateAutoSyncTimer = Timer.publish(every: hours * 60 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.runScheduledUpstreamRateAutoSync() }
            }
    }

    func startUpstreamBalanceRefreshTimer() {
        upstreamBalanceRefreshTimer?.cancel()
        upstreamBalanceRefreshTimer = Timer.publish(every: CCHUpstreamRateStorage.balanceRefreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshUpstreamBalances(silent: true, onlyIfStale: true) }
            }
    }

    func runScheduledUpstreamRateAutoSync() async {
        guard upstreamRateAutoSyncEnabled else { return }
        await refreshUpstreamRates(silent: true)
    }

    func updateProviderMultiplier(_ provider: CCHProvider, multiplier: Double) async {
        guard multiplier >= 0 else {
            flashActionMessage("倍率不能为负数", duration: 4, isWarning: true)
            return
        }
        if providerMultiplierUpdatingIds.contains(provider.id) {
            return
        }

        let normalized = (multiplier * 10_000).rounded() / 10_000
        actionMessageDismissTask?.cancel()
        actionMessage = "更新倍率 \(provider.name): \(formatMultiplier(normalized))..."
        actionMessageIsWarning = false
        providerMultiplierUpdatingIds.insert(provider.id)
        defer {
            providerMultiplierUpdatingIds.remove(provider.id)
        }

        do {
            try await api.setProviderMultiplier(config: config, providerId: provider.id, multiplier: normalized)
            flashActionMessage("倍率已更新 \(provider.name): \(formatMultiplier(normalized))")
            _ = await loadProviders()
        } catch {
            flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
        }
    }

    func testProviderModel(_ provider: CCHProvider, model: String? = nil) async {
        let requestedModel = model?.trimmingCharacters(in: .whitespacesAndNewlines)
        await testProviderModels(provider, models: [requestedModel?.isEmpty == false ? requestedModel! : provider.testModel])
    }

    func testProviderModels(_ provider: CCHProvider, models: [String]) async {
        if modelTestingProviderIds.contains(provider.id) {
            return
        }

        let requestedModels = normalizedProviderTestModels(models)
        let testModels = requestedModels.isEmpty ? [provider.testModel] : requestedModels
        guard !testModels.isEmpty else {
            flashActionMessage("模型名称不能为空", duration: 4, isWarning: true)
            return
        }

        actionMessageDismissTask?.cancel()
        actionMessage = testModels.count > 1
            ? "模型测试 \(provider.name): 0/\(testModels.count)..."
            : "模型测试 \(provider.name): \(testModels[0])..."
        actionMessageIsWarning = false
        providerModelTestResults[provider.id] = nil
        providerModelTestResultsByModel[provider.id] = [:]
        modelTestingProviderIds.insert(provider.id)
        defer {
            modelTestingProviderIds.remove(provider.id)
            providerModelTestProgress[provider.id] = nil
        }

        for (index, testModel) in testModels.enumerated() {
            providerModelTestProgress[provider.id] = CCHProviderModelTestProgress(
                completed: index,
                total: testModels.count,
                currentModel: testModel
            )

            do {
                let result = try await api.testProviderModel(config: config, provider: provider, model: testModel)
                providerModelTestResults[provider.id] = result
                providerModelTestResultsByModel[provider.id, default: [:]][testModel] = result
            } catch {
                let failedResult = CCHProviderModelTestResult(
                    success: false,
                    status: "red",
                    message: "模型测试失败",
                    latencyMs: nil,
                    model: testModel,
                    httpStatusCode: nil,
                    errorMessage: error.localizedDescription
                )
                providerModelTestResults[provider.id] = failedResult
                providerModelTestResultsByModel[provider.id, default: [:]][testModel] = failedResult
            }

            providerModelTestProgress[provider.id] = CCHProviderModelTestProgress(
                completed: index + 1,
                total: testModels.count,
                currentModel: testModel
            )
            if testModels.count > 1 {
                actionMessage = "模型测试 \(provider.name): \(index + 1)/\(testModels.count)"
            }
        }

        let results = providerModelTestResultsByModel[provider.id] ?? [:]
        let availableCount = results.values.filter { result in
            result.success || result.status.lowercased() == "green"
        }.count
        let warningCount = results.values.filter { $0.status.lowercased() == "yellow" }.count
        if testModels.count > 1 {
            let failedCount = max(0, testModels.count - availableCount - warningCount)
            flashActionMessage(
                "模型测试 \(provider.name): 可用 \(availableCount) · 波动 \(warningCount) · 失败 \(failedCount)",
                duration: failedCount > 0 ? 6 : 4,
                isWarning: failedCount > 0
            )
        } else if let result = providerModelTestResults[provider.id] {
            let latency = result.latencyMs.map(formatProbeLatency) ?? "-"
            let displayModel = result.model.isEmpty ? testModels[0] : result.model
            let status = result.status.lowercased()
            if result.success || status == "green" {
                flashActionMessage("模型测试 \(provider.name): 可用 \(latency) · \(displayModel)")
            } else if status == "yellow" {
                flashActionMessage("模型测试 \(provider.name): 波动 \(latency) · \(displayModel)", duration: 5, isWarning: true)
            } else {
                let detail = result.errorMessage.isEmpty ? result.message : result.errorMessage
                flashActionMessage("模型测试 \(provider.name): \(detail)", duration: 6, isWarning: true)
            }
        }
        _ = await loadProviders()
    }

    private func flashActionMessage(_ message: String, duration: TimeInterval = 2.6, isWarning: Bool = false) {
        let duration = min(duration, 6)
        actionMessageDismissTask?.cancel()
        actionMessageIsWarning = isWarning
        actionMessage = message
        actionMessageDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if self.actionMessage == message {
                self.actionMessage = nil
                self.actionMessageIsWarning = false
            }
        }
    }

    func openCCH(_ path: String = "/zh-CN/dashboard") {
        let base = cchBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + path) else { return }
        NSWorkspace.shared.open(url)
    }

    private func runRefresh(
        _ key: CCHRefreshKey,
        operation: @escaping @MainActor () async -> String?
    ) async -> String? {
        if let slot = refreshTasks[key] {
            return await slot.task.value
        }

        let id = UUID()
        let task = Task { @MainActor in
            await operation()
        }
        refreshTasks[key] = CCHRefreshTaskSlot(id: id, task: task)
        let result = await task.value
        if refreshTasks[key]?.id == id {
            refreshTasks[key] = nil
        }
        return result
    }

    private func shouldRefreshProviderUsage(now: Date = Date()) -> Bool {
        guard let lastProviderUsageRefresh else { return true }
        return now.timeIntervalSince(lastProviderUsageRefresh) >= 30
    }

    private func shouldRefreshProviderGroups(now: Date = Date()) -> Bool {
        guard let lastProviderGroupsRefresh else { return true }
        return now.timeIntervalSince(lastProviderGroupsRefresh) >= 60
    }

    private func shouldRefreshLogSummary(now: Date = Date()) -> Bool {
        guard let lastLogSummaryRefresh else { return true }
        return now.timeIntervalSince(lastLogSummaryRefresh) >= 15
    }

    private func shouldRefreshStatusBarData(now: Date = Date()) -> Bool {
        statusBarPollingPolicy.shouldRefreshData(
            lastRefresh: lastStatusBarDataRefresh,
            hasRunningItems: !cachedMenuBarRunningLogs.isEmpty,
            lastRunningSeenAt: lastStatusBarRunningSeenAt,
            now: now
        )
    }

    private func shouldRefreshStatusBarOverview(now: Date = Date()) -> Bool {
        statusBarPollingPolicy.shouldRefreshOverview(
            lastRefresh: lastStatusBarOverviewRefresh,
            now: now
        )
    }

    private func loadOverview() async -> String? {
        do {
            overview = try await api.fetchOverview(config: config)
            updateStatusBarSnapshot()
            return nil
        } catch {
            return "总览: \(error.localizedDescription)"
        }
    }

    private func loadActiveSessions() async -> String? {
        do {
            activeSessions = try await api.fetchActiveSessions(config: config)
            updateStatusBarSnapshot()
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
            rebuildLeaderboardSummary()
            return nil
        } catch {
            leaderboard = []
            rebuildLeaderboardSummary()
            return "排行: \(error.localizedDescription)"
        }
    }

    private func loadRecentLogsForStatusBar() async -> String? {
        do {
            let page = try await api.fetchLogs(
                config: config,
                page: 1,
                pageSize: 40,
                startDate: Calendar.current.date(byAdding: .hour, value: -1, to: Date()),
                model: "",
                statusCode: "",
                sessionId: "",
                includeStats: false
            )
            registerIncomingLogs(page.logs, isReset: true, context: .recent)
            recentLogs = page.logs
            mergeRecentLogHistory(page.logs)
            rebuildCacheStatus()
            return nil
        } catch {
            return "日志: \(error.localizedDescription)"
        }
    }

    private func loadLogs(reset: Bool = true, includeStats: Bool = true) async -> String? {
        do {
            let nextPage = reset ? 1 : logPage + 1
            let page = try await api.fetchLogs(
                config: config,
                page: nextPage,
                pageSize: 50,
                startDate: logRange.startDate,
                model: logModelFilter,
                statusCode: logStatusFilter,
                sessionId: logSessionFilter,
                includeStats: includeStats
            )
            registerIncomingLogs(page.logs, isReset: reset, context: .logsPage)
            logPage = nextPage
            if reset {
                logs = page.logs
            } else {
                let existingIds = Set(logs.map(\.id))
                logs.append(contentsOf: page.logs.filter { !existingIds.contains($0.id) })
            }
            if logModelFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               logStatusFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               logSessionFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recentLogs = Array(logs.prefix(80))
                mergeRecentLogHistory(recentLogs)
            }
            rebuildCacheStatus()
            logTotal = page.total
            if includeStats {
                logSummary = page.summary
                lastLogSummaryRefresh = Date()
            }
            if let selectedLog, !page.logs.contains(where: { $0.id == selectedLog.id }) {
                self.selectedLog = nil
            }
            return nil
        } catch {
            return "日志: \(error.localizedDescription)"
        }
    }

    private func loadProviders(includeUsage: Bool = true) async -> String? {
        do {
            providers = try await api.fetchProviders(config: config, includeUsage: includeUsage)
            if shouldRefreshProviderGroups() {
                if let groups = try? await api.fetchProviderGroups(config: config) {
                    officialProviderGroups = groups
                    lastProviderGroupsRefresh = Date()
                }
            }
            assignableProviderGroups = mergedAssignableProviderGroups(officialProviderGroups)
            if includeUsage {
                lastProviderUsageRefresh = Date()
            }
            reconcileProviderGroupAssignmentOverrides()
            rebuildProviderLookup()
            let allGroups = computedProviderGroups()
            selectedProviderGroups = selectedProviderGroups.intersection(Set(allGroups))
            rebuildProviderFilterSnapshot(groups: allGroups)
            updateStatusBarSnapshot()
            return nil
        } catch {
            return "渠道: \(error.localizedDescription)"
        }
    }

    private func registerIncomingLogs(_ values: [CCHLogEntry], isReset: Bool, context: CCHLogHighlightContext) {
        let ids = Set(values.map(\.id))
        let knownIds: Set<Int>
        switch context {
        case .recent: knownIds = knownRecentLogIds
        case .logsPage: knownIds = knownLogPageIds
        }
        defer {
            switch context {
            case .recent:
                rememberKnownLogIds(ids, idsSet: &knownRecentLogIds, order: &knownRecentLogIdOrder)
            case .logsPage:
                rememberKnownLogIds(ids, idsSet: &knownLogPageIds, order: &knownLogPageIdOrder)
            }
        }

        guard isReset, !knownIds.isEmpty else { return }
        let newIds = ids.subtracting(knownIds)
        guard !newIds.isEmpty else { return }

        highlightedLogIds.formUnion(newIds)
        for id in newIds {
            highlightedLogDismissTasks[id]?.cancel()
            highlightedLogDismissTasks[id] = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                self.highlightedLogIds.remove(id)
                self.highlightedLogDismissTasks[id] = nil
            }
        }
    }

    private func rememberKnownLogIds(_ ids: Set<Int>, idsSet: inout Set<Int>, order: inout [Int]) {
        for id in ids.sorted(by: >) where idsSet.insert(id).inserted {
            order.append(id)
        }

        guard order.count > CCHRetentionLimits.knownLogIds else { return }
        let overflow = order.count - CCHRetentionLimits.knownLogIds
        let removed = order.prefix(overflow)
        idsSet.subtract(removed)
        order.removeFirst(overflow)
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

    private func rebuildCacheStatus() {
        let combined = uniqueLogs(recentLogs + logs + recentLogHistory)
        let next = buildCacheStatusMap(for: combined)
        cacheStatusByLogId = next
        rebuildMenuBarRunningLogs()
        announceLatestCacheAlert(from: combined, statusMap: next)
        updateStatusBarSnapshot()
    }

    private func rebuildProviderLookup() {
        providerMultiplierByName = Dictionary(
            providers.map { ($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0.costMultiplier) },
            uniquingKeysWith: { current, _ in current }
        )
        providerMultiplierByProviderId = Dictionary(
            providers.map { ($0.id, $0.costMultiplier) },
            uniquingKeysWith: { current, _ in current }
        )
        pruneUpstreamRateSelections()
    }

    private func computedProviderGroups() -> [String] {
        let groups = Set(providers.flatMap { displayGroupTitles(for: $0) })
        return ["全部"] + groups.filter { $0 != "全部" }.sorted()
    }

    private func mergedAssignableProviderGroups(_ officialGroups: [CCHProviderGroup]) -> [CCHProviderGroup] {
        var seen = Set<String>()
        var merged: [CCHProviderGroup] = []

        for group in officialGroups {
            let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.lowercased()
            guard !name.isEmpty, !isDefaultProviderGroup(name), seen.insert(key).inserted else { continue }
            merged.append(group)
        }

        let existingGroups = providers
            .flatMap { providerGroupTitles($0.groupTag) }
            .filter { !isDefaultProviderGroup($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        for name in existingGroups {
            let key = name.lowercased()
            guard seen.insert(key).inserted else { continue }
            merged.append(CCHProviderGroup(id: name, name: name, providerCount: nil, costMultiplier: nil))
        }

        return merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func providerGroupTag(from groups: Set<String>) -> String? {
        let values = groups
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isDefaultProviderGroup($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return values.isEmpty ? nil : values.joined(separator: ",")
    }

    private func storedGroupNames(for provider: CCHProvider) -> Set<String> {
        Set(providerGroupTitles(provider.groupTag).filter { !isDefaultProviderGroup($0) })
    }

    private func reconcileProviderGroupAssignmentOverrides() {
        var nextOverrides = providerGroupAssignmentOverrides
        for provider in providers where nextOverrides[provider.id] == storedGroupNames(for: provider) {
            nextOverrides[provider.id] = nil
        }
        let providerIds = Set(providers.map(\.id))
        nextOverrides = nextOverrides.filter { providerIds.contains($0.key) }
        providerGroupAssignmentOverrides = nextOverrides
    }

    private func rebuildProviderFilterSnapshot(groups: [String]? = nil) {
        let resolvedGroups = groups ?? computedProviderGroups()
        let filtered: [CCHProvider]
        if selectedProviderGroups.isEmpty {
            filtered = providers
        } else {
            filtered = providers.filter { provider in
                !Set(displayGroupTitles(for: provider)).isDisjoint(with: selectedProviderGroups)
            }
        }
        providerFilterSnapshot = CCHProviderFilterSnapshot(
            groups: resolvedGroups,
            providers: filtered,
            enabledCount: filtered.filter(\.isEnabled).count,
            unhealthyCount: filtered.filter { $0.health.circuitState.lowercased() != "closed" || $0.health.failureCount > 0 }.count
        )
    }

    private func rebuildLeaderboardSummary() {
        let requests = leaderboard.reduce(0) { $0 + $1.requests }
        let cost = leaderboard.reduce(0) { $0 + $1.cost }
        let tokens = leaderboard.reduce(0) { $0 + $1.tokens }
        let rows = leaderboard.filter { $0.cacheHitRateOverride != nil && $0.inputTokens > 0 }
        let totalInputTokens = rows.reduce(0) { $0 + $1.inputTokens }
        let cacheHitRate: Double?
        if rows.isEmpty || totalInputTokens <= 0 {
            cacheHitRate = nil
        } else {
            let weighted = rows.reduce(0.0) { partial, entry in
                partial + (entry.cacheHitRateOverride ?? 0) * Double(entry.inputTokens)
            }
            cacheHitRate = min(1, max(0, weighted / Double(totalInputTokens)))
        }
        leaderboardSummary = CCHLeaderboardSummary(
            requests: requests,
            cost: cost,
            tokens: tokens,
            cacheHitRate: cacheHitRate
        )
    }

    private func rebuildMenuBarRunningLogs() {
        let ordered = recentLogs.sorted { lhs, rhs in
            if lhs.id != rhs.id { return lhs.id > rhs.id }
            if lhs.requestSequence != rhs.requestSequence {
                return lhs.requestSequence > rhs.requestSequence
            }
            return (parsedCCHDate(lhs.createdAt) ?? .distantPast) > (parsedCCHDate(rhs.createdAt) ?? .distantPast)
        }

        var seenSessionIds = Set<String>()
        cachedMenuBarRunningLogs = ordered.compactMap { log in
            guard log.statusCode == nil else { return nil }
            let key = log.sessionId.isEmpty ? "log-\(log.id)" : log.sessionId
            guard seenSessionIds.insert(key).inserted else { return nil }
            return log
        }
        if !cachedMenuBarRunningLogs.isEmpty {
            lastStatusBarRunningSeenAt = Date()
        }
    }

    private func updateStatusBarSnapshot() {
        let runningItems = statusBarRunningItems()

        let next = CCHStatusBarSnapshot(
            showsDetails: showStatusBarDetails,
            idlePrimary: menuBarText,
            idleDetail: menuBarIdleDetail,
            idleCacheState: statusBarCacheState,
            runningItems: runningItems,
            hasRecentLogs: !recentLogs.isEmpty,
            generatedAt: Date()
        )

        if statusBarSnapshot != next {
            statusBarSnapshot = next
        }
    }

    private func statusBarRunningItems() -> [CCHStatusRunningItem] {
        cachedMenuBarRunningLogs.map(statusBarRunningItem)
    }

    private func statusBarRunningItem(from log: CCHLogEntry) -> CCHStatusRunningItem {
        let model = firstNonEmpty(log.model, log.originalModel, "model")
        return CCHStatusRunningItem(
            id: log.sessionId.isEmpty ? "log-\(log.id)" : log.sessionId,
            logId: log.id,
            providerName: firstNonEmpty(log.providerName, "Provider"),
            model: model,
            multiplier: log.costMultiplier,
            isFastTier: log.isFastTier,
            isRetrying: false,
            startedAt: parsedCCHDate(log.createdAt),
            cacheState: cacheStatus(for: log).state
        )
    }

    private func mergeRecentLogHistory(_ values: [CCHLogEntry]) {
        let merged = uniqueLogs(values + recentLogHistory)
            .sorted(by: isNewerLog)
        recentLogHistory = Array(merged.prefix(CCHRetentionLimits.recentLogHistory))
    }

    private func uniqueLogs(_ values: [CCHLogEntry]) -> [CCHLogEntry] {
        var seen = Set<Int>()
        return values.filter { seen.insert($0.id).inserted }
    }

    private func announceLatestCacheAlert(from values: [CCHLogEntry], statusMap: [Int: CCHCacheStatusContext]) {
        guard let latest = values
            .filter({ statusMap[$0.id]?.state == .rebuilding })
            .sorted(by: isNewerLog)
            .first
        else { return }

        guard latest.id != lastAnnouncedCacheAlertLogId else { return }
        lastAnnouncedCacheAlertLogId = latest.id
        menuBarCacheAlertLogId = latest.id
        cacheAlertDismissTask?.cancel()
        cacheAlertDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            if self.menuBarCacheAlertLogId == latest.id {
                self.menuBarCacheAlertLogId = nil
                self.updateStatusBarSnapshot()
            }
        }
    }

    func startUpdateCheckTimer() {
        updateCheckTimer?.cancel()
        let interval: TimeInterval = 6 * 60 * 60
        updateCheckTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.checkForUpdates(force: false) }
            }
    }

    func checkForUpdates(force: Bool) async {
        if isCheckingForUpdate { return }
        if !force, !checkForUpdatesEnabled { return }
        isCheckingForUpdate = true
        defer { isCheckingForUpdate = false }
        do {
            let release = try await api.fetchLatestRelease(
                owner: "xt1990xt1990",
                repo: "Claude-Code-Hub-Bar"
            )
            lastUpdateCheck = Date()
            updateCheckError = nil
            let normalized = normalizeReleaseVersion(release.tag)
            guard !normalized.isEmpty else {
                availableUpdate = nil
                return
            }
            let comparison = compareSemver(normalized, appVersion)
            if comparison == .orderedDescending {
                if force || normalized != dismissedUpdateVersion {
                    availableUpdate = CCHAvailableUpdate(
                        version: normalized,
                        displayName: release.name.isEmpty ? "v\(normalized)" : release.name,
                        releaseURL: release.htmlURL,
                        body: release.body,
                        publishedAt: release.publishedAt
                    )
                } else {
                    availableUpdate = nil
                }
            } else {
                availableUpdate = nil
            }
        } catch {
            lastUpdateCheck = Date()
            updateCheckError = error.localizedDescription
        }
    }

    func dismissAvailableUpdate() {
        if let version = availableUpdate?.version {
            dismissedUpdateVersion = version
        }
        availableUpdate = nil
    }

    func openLatestRelease() {
        if let url = availableUpdate?.releaseURL {
            NSWorkspace.shared.open(url)
            return
        }
        if let url = URL(string: "https://github.com/xt1990xt1990/Claude-Code-Hub-Bar/releases") {
            NSWorkspace.shared.open(url)
        }
    }

}

private extension MonitorState {
    static func loadProviderCustomTestModels() -> [Int: [String]] {
        guard
            let data = UserDefaults.standard.data(forKey: CCHProviderModelTestLimits.storageKey),
            let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }

        var result: [Int: [String]] = [:]
        for (key, models) in decoded {
            guard let providerId = Int(key) else { continue }
            let normalized = normalizedProviderTestModels(models)
            if !normalized.isEmpty {
                result[providerId] = Array(normalized.prefix(CCHProviderModelTestLimits.maxCustomModels))
            }
        }
        return result
    }

    func saveProviderCustomTestModels() {
        var encodable: [String: [String]] = [:]
        for (providerId, models) in providerCustomTestModels {
            let normalized = Array(normalizedProviderTestModels(models).prefix(CCHProviderModelTestLimits.maxCustomModels))
            if !normalized.isEmpty {
                encodable[String(providerId)] = normalized
            }
        }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: CCHProviderModelTestLimits.storageKey)
        }
    }

    static func loadIntSet(key: String) -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }

    static func loadStringSet(key: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func saveUpstreamRateSelectedProviderIds() {
        UserDefaults.standard.set(upstreamRateSelectedProviderIds.sorted(), forKey: CCHUpstreamRateStorage.selectedProviderIdsKey)
    }

    func saveUpstreamRateIgnoredHosts() {
        UserDefaults.standard.set(upstreamRateIgnoredHosts.sorted(), forKey: CCHUpstreamRateStorage.ignoredHostsKey)
    }

    func saveUpstreamRateSourceTypeOverrides() {
        let encodable = upstreamRateSourceTypeOverrides.mapValues(\.rawValue)
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: CCHUpstreamRateStorage.sourceTypeOverridesKey)
        }
    }

    func saveUpstreamRateHostDisplayNames() {
        let encodable = upstreamRateHostDisplayNames.reduce(into: [String: String]()) { result, entry in
            let normalizedHost = normalizedUpstreamHost(entry.key) ?? entry.key.lowercased()
            let name = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, name != normalizedHost {
                result[normalizedHost] = name
            }
        }
        upstreamRateHostDisplayNames = encodable
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: CCHUpstreamRateStorage.hostDisplayNamesKey)
        }
    }

    static func loadUpstreamRateSourceTypeOverrides() -> [String: UpstreamRateSourceType] {
        guard
            let data = UserDefaults.standard.data(forKey: CCHUpstreamRateStorage.sourceTypeOverridesKey),
            let raw = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return raw.reduce(into: [String: UpstreamRateSourceType]()) { result, entry in
            if let type = UpstreamRateSourceType(rawValue: entry.value), type != .unknown {
                result[entry.key] = type
            }
        }
    }

    static func loadUpstreamRateHostDisplayNames() -> [String: String] {
        guard
            let data = UserDefaults.standard.data(forKey: CCHUpstreamRateStorage.hostDisplayNamesKey),
            let raw = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return raw.reduce(into: [String: String]()) { result, entry in
            let normalizedHost = normalizedUpstreamHost(entry.key) ?? entry.key.lowercased()
            let name = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, name != normalizedHost {
                result[normalizedHost] = name
            }
        }
    }

    static func loadUpstreamRateSnapshots() -> [UpstreamRateSnapshot] {
        guard
            let data = UserDefaults.standard.data(forKey: CCHUpstreamRateStorage.snapshotsKey),
            let snapshots = try? JSONDecoder().decode([UpstreamRateSnapshot].self, from: data)
        else {
            return []
        }
        return snapshots
    }

    func saveUpstreamRateSnapshots() {
        if let data = try? JSONEncoder().encode(upstreamRateSnapshots) {
            UserDefaults.standard.set(data, forKey: CCHUpstreamRateStorage.snapshotsKey)
        }
    }

    func pruneUpstreamRateSelections() {
        let providerIds = Set(providers.map(\.id))
        let nextSelected = upstreamRateSelectedProviderIds.intersection(providerIds)
        if nextSelected != upstreamRateSelectedProviderIds {
            upstreamRateSelectedProviderIds = nextSelected
            saveUpstreamRateSelectedProviderIds()
        }
    }

    @discardableResult
    func upsertUpstreamCredential(_ credential: UpstreamRateCredential, persist: Bool) -> Bool {
        let credential = mergedUpstreamCredential(credential)
        var next = upstreamRateCredentials.filter { $0.host != credential.host }
        next.append(credential)
        upstreamRateCredentials = next.sorted { $0.host < $1.host }
        if persist {
            do {
                try upstreamCredentialStore.save(upstreamRateCredentials)
            } catch {
                flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
                return false
            }
        }
        return true
    }

    private func mergedUpstreamCredential(_ credential: UpstreamRateCredential) -> UpstreamRateCredential {
        guard let existing = upstreamRateCredentials.first(where: { $0.host == credential.host }) else {
            return credential
        }
        var next = credential
        if next.sub2AuthToken.isEmpty {
            next.sub2AuthToken = existing.sub2AuthToken
        }
        if next.sub2RefreshToken.isEmpty {
            next.sub2RefreshToken = existing.sub2RefreshToken
        }
        if next.sub2TokenExpiresAt == nil {
            next.sub2TokenExpiresAt = existing.sub2TokenExpiresAt
        }
        if next.newAPIUserId.isEmpty {
            next.newAPIUserId = existing.newAPIUserId
        }
        if next.newAPIAccessToken.isEmpty {
            next.newAPIAccessToken = existing.newAPIAccessToken
        }
        if next.newAPICookieHeader.isEmpty {
            next.newAPICookieHeader = existing.newAPICookieHeader
        }
        return next
    }

    func upsertLocalUpstreamRateSnapshot(host: String, sourceType: UpstreamRateSourceType, status: UpstreamRateSourceStatus) {
        let normalizedHost = normalizedUpstreamHost(host) ?? host.lowercased()
        upstreamRateSnapshots.removeAll { $0.host == normalizedHost }
        upstreamRateSnapshots.append(UpstreamRateSnapshot(host: normalizedHost, sourceType: sourceType, status: status))
    }

    func upstreamRateTargets(for providers: [UpstreamRateProviderInput]) async -> [UpstreamRateTarget] {
        var targets: [UpstreamRateTarget] = []
        for provider in providers {
            do {
                let key = try await api.revealProviderKey(config: config, providerId: provider.id)
                targets.append(UpstreamRateTarget(providerId: provider.id, providerName: provider.name, apiKey: key))
            } catch {
                continue
            }
        }
        return targets
    }

    func upstreamProviderInput(_ provider: CCHProvider) -> UpstreamRateProviderInput {
        UpstreamRateProviderInput(
            id: provider.id,
            name: provider.name,
            apiURL: provider.apiURL,
            websiteURL: provider.websiteURL,
            groupTag: provider.groupTag,
            costMultiplier: provider.costMultiplier,
            isEnabled: provider.isEnabled
        )
    }

    func buildLocalUpstreamRateSnapshots() -> [UpstreamRateSnapshot] {
        let inputs = providers.map(upstreamProviderInput)
        let grouped = Dictionary(grouping: inputs) { input in
            UpstreamRateMatcher.providerHost(input) ?? "unknown-\(input.id)"
        }

        return grouped.compactMap { host, values in
            let sourceType = localDetectedSourceType(host: host)
            guard sourceType != .unknown else { return nil }

            let entries = values
                .map { provider in
                    UpstreamRateEntry(
                        providerId: provider.id,
                        keyName: provider.name,
                        groupName: displayUpstreamGroupName(provider),
                        rate: provider.costMultiplier
                    )
                }

            return UpstreamRateSnapshot(
                host: host,
                sourceType: sourceType,
                status: .available,
                entries: entries
            )
        }
    }

    func localDetectedSourceType(host: String) -> UpstreamRateSourceType {
        let value = (normalizedUpstreamHost(host) ?? host).lowercased()
        if let override = upstreamRateSourceTypeOverrides[value] {
            return override
        }
        if value.contains("zzshu") || value.contains("xixi") || value.contains("new-api") {
            return .newAPI
        }
        if value.contains("sub2") || value.hasPrefix("sub.") || value.contains("kedaya") || value.contains("nightyu") || value.contains("lucen") {
            return .sub2API
        }
        return .unknown
    }

    func resolvedUpstreamRateSourceType(host: String) async -> UpstreamRateSourceType {
        let normalizedHost = normalizedUpstreamHost(host) ?? host.lowercased()
        let local = localDetectedSourceType(host: normalizedHost)
        if local != .unknown {
            return local
        }
        let detected = await upstreamRateService.detectSite(baseURL: "https://\(normalizedHost)", host: normalizedHost)
        if detected != .unknown {
            upstreamRateSourceTypeOverrides[normalizedHost] = detected
            saveUpstreamRateSourceTypeOverrides()
        }
        return detected
    }

    func displayUpstreamGroupName(_ provider: UpstreamRateProviderInput) -> String {
        let groups = providerGroupTitles(provider.groupTag).filter { !isDefaultProviderGroup($0) }
        if let first = groups.first {
            return first
        }
        return provider.name
    }
}

private func buildCacheStatusMap(for logs: [CCHLogEntry]) -> [Int: CCHCacheStatusContext] {
    var result: [Int: CCHCacheStatusContext] = [:]
    for group in Dictionary(grouping: logs, by: cacheSessionKey).values {
        let ordered = group
            .filter { $0.statusCode.map { (200..<300).contains($0) } ?? false }
            .sorted(by: isOlderLog)
        var previous: CCHLogEntry?
        for log in ordered {
            let state = isLargeCacheDrop(log, previous: previous) ? CCHCacheVisibilityState.rebuilding : .normal
            result[log.id] = CCHCacheStatusContext(
                state: state,
                createdTokens: log.cacheCreationTokens,
                readTokens: log.cacheReadTokens
            )
            if log.inputTokens > 0 || log.cacheReadTokens > 0 || log.totalTokens > 0 {
                previous = log
            }
        }
    }
    for log in logs where result[log.id] == nil {
        result[log.id] = CCHCacheStatusContext(
            state: .normal,
            createdTokens: log.cacheCreationTokens,
            readTokens: log.cacheReadTokens
        )
    }
    return result
}

private func isLargeCacheDrop(_ log: CCHLogEntry, previous: CCHLogEntry?) -> Bool {
    guard
        let previous,
        log.inputTokens >= 20_000,
        log.cacheReadTokens <= max(2_500, log.inputTokens / 18),
        previous.cacheReadTokens >= 15_000,
        !isCompactCacheRequest(log)
    else { return false }

    let previousCachedContext = previous.inputTokens + previous.cacheReadTokens
    guard previousCachedContext >= 20_000 else { return false }
    let ratio = Double(log.inputTokens) / Double(previousCachedContext)
    return ratio >= 0.55 && ratio <= 1.55
}

private func isCompactCacheRequest(_ log: CCHLogEntry) -> Bool {
    let modelText = "\(log.model) \(log.originalModel)".lowercased()
    if modelText.contains("compact") { return true }
    if log.messagesCount > 0, log.messagesCount < 12 { return true }
    return false
}

private func cacheSessionKey(_ log: CCHLogEntry) -> String {
    log.sessionId.isEmpty ? "log-\(log.id)" : log.sessionId
}

private func isOlderLog(_ lhs: CCHLogEntry, _ rhs: CCHLogEntry) -> Bool {
    if lhs.sessionId == rhs.sessionId, lhs.requestSequence != rhs.requestSequence {
        return lhs.requestSequence < rhs.requestSequence
    }
    guard
        let lhsDate = parsedCCHDate(lhs.createdAt),
        let rhsDate = parsedCCHDate(rhs.createdAt)
    else { return lhs.id < rhs.id }
    return lhsDate < rhsDate
}

private func isNewerLog(_ lhs: CCHLogEntry, _ rhs: CCHLogEntry) -> Bool {
    guard
        let lhsDate = parsedCCHDate(lhs.createdAt),
        let rhsDate = parsedCCHDate(rhs.createdAt)
    else { return lhs.id > rhs.id }
    return lhsDate > rhsDate
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

private func firstNonEmpty(_ values: String?...) -> String {
    for value in values {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    return ""
}

private func menuBarActivityScore(_ session: CCHActiveSession) -> Int {
    if session.concurrentCount > 0 { return 300 }
    if session.status.lowercased().contains("retry") { return 200 }
    if isRunningStatus(session.status) { return 100 }
    return 0
}

func formatMoney(_ value: Double) -> String {
    let parts = moneyDisplayParts(value)
    return parts.major + (parts.minor ?? "")
}

func formatStatusBarMoney(_ value: Double) -> String {
    guard value.isFinite else { return "$0.000" }
    return String(format: "$%.3f", value)
}

func moneyParts(_ value: Double) -> (major: String, minor: String?) {
    moneyDisplayParts(value)
}

func moneyDisplayParts(_ value: Double) -> (major: String, minor: String?) {
    guard value.isFinite else { return ("$0.00", nil) }
    let absValue = abs(value)
    if absValue >= 1000 {
        return (String(format: "$%.1fk", value / 1000), nil)
    }
    if absValue >= 100 {
        return (String(format: "$%.0f", value), nil)
    }

    let trimmed = trimMoneySuffix(String(format: "$%.6f", value))
    let parts = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return (trimmed, nil) }

    let fraction = String(parts[1])
    guard fraction.count > 3 else { return (trimmed, nil) }

    let major = String(parts[0]) + "." + String(fraction.prefix(3))
    let minor = String(fraction.dropFirst(3))
    return (major, minor.isEmpty ? nil : minor)
}

private func trimMoneySuffix(_ value: String) -> String {
    var text = value
    while text.last == "0" {
        text.removeLast()
    }
    if text.last == "." {
        text.removeLast()
    }
    return text == "$0" ? "$0.00" : text
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

func formatProbeLatency(_ value: Double?) -> String {
    guard let value else { return "正常" }
    if value < 1000 {
        return value < 10 ? String(format: "%.1fms", value) : String(format: "%.0fms", value)
    }
    return String(format: "%.2fs", value / 1000)
}

func normalizedProviderTestModel(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}

func normalizedProviderTestModels(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for value in values {
        let normalized = normalizedProviderTestModel(value)
        guard !normalized.isEmpty else { continue }
        let key = normalized.lowercased()
        guard seen.insert(key).inserted else { continue }
        result.append(normalized)
        if result.count >= CCHProviderModelTestLimits.maxCustomModels {
            break
        }
    }
    return result
}

func formatTokensPerSecond(_ value: Double?) -> String {
    guard let value, value > 0 else { return "-- tok/s" }
    return String(format: "%.0f tok/s", value)
}

func shouldHideOutputRate(outputRate: Double?, durationMs: Int?, ttfbMs: Int?) -> Bool {
    guard
        let outputRate,
        outputRate.isFinite,
        let durationMs,
        durationMs > 0,
        let ttfbMs
    else { return false }

    let generationTimeMs = durationMs - ttfbMs
    guard generationTimeMs > 0 else { return false }
    let ratio = Double(generationTimeMs) / Double(durationMs)
    return ratio < 0.1 && outputRate > 5000
}

func computedTokensPerSecond(outputTokens: Int, durationMs: Int?, ttfbMs: Int?) -> Double? {
    guard
        outputTokens > 0,
        let durationMs,
        durationMs > 0
    else { return nil }
    let generationMs = max(1, durationMs - (ttfbMs ?? 0))
    let outputRate = Double(outputTokens) / (Double(generationMs) / 1000)
    return shouldHideOutputRate(outputRate: outputRate, durationMs: durationMs, ttfbMs: ttfbMs) ? nil : outputRate
}

func normalizedTokensPerSecond(
    raw: Double?,
    outputTokens: Int,
    durationMs: Int?,
    ttfbMs: Int?
) -> Double? {
    if let raw, shouldHideOutputRate(outputRate: raw, durationMs: durationMs, ttfbMs: ttfbMs) {
        return nil
    }
    if let raw, raw > 0 {
        return raw
    }
    return computedTokensPerSecond(outputTokens: outputTokens, durationMs: durationMs, ttfbMs: ttfbMs)
}

func cacheHitRate(cacheReadTokens: Int, inputTokens: Int) -> Double {
    let totalCacheableInput = inputTokens + cacheReadTokens
    guard totalCacheableInput > 0 else { return 0 }
    return min(1, max(0, Double(cacheReadTokens) / Double(totalCacheableInput)))
}

func cacheRateColor(_ rate: Double?) -> Color {
    guard let rate else { return .secondary }
    switch rate {
    case let value where value >= 0.85:
        return .green
    case let value where value >= 0.6:
        return .yellow
    default:
        return .orange
    }
}

func formatMultiplier(_ value: Double) -> String {
    if abs(value - 1) < 0.001 {
        return "x1"
    }
    if value.rounded() == value {
        return String(format: "x%.0f", value)
    }
    let roundedToTwo = (value * 100).rounded() / 100
    let format = abs(value - roundedToTwo) < 0.0001 ? "x%.2f" : "x%.3f"
    return String(format: format, value)
}

func multiplierLevel(_ value: Double) -> Int {
    if value <= 0.5 { return 0 }
    if value <= 1.0 { return 1 }
    if value <= 2.0 { return 2 }
    return 3
}

func compactScrollingText(_ value: String, visibleCharacters: Int) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > visibleCharacters, visibleCharacters > 0 else {
        return trimmed
    }
    guard visibleCharacters > 1 else { return String(trimmed.prefix(visibleCharacters)) }
    return String(trimmed.prefix(visibleCharacters - 1)) + "…"
}

func shortTime(_ raw: String) -> String {
    guard let date = parsedCCHDate(raw) else {
        return raw
    }
    return date.formatted(date: .omitted, time: .shortened)
}

func providerGroupTitle(_ value: String) -> String {
    providerGroupTitles(value).first ?? "默认"
}

func providerGroupTitles(_ value: String) -> [String] {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isDefaultProviderGroup(trimmed) else { return ["默认"] }
    let groups = trimmed
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !isDefaultProviderGroup($0) }
    return groups.isEmpty ? ["默认"] : groups
}

func isDefaultProviderGroup(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty || normalized == "默认" || normalized == "default"
}

func providerGroupColor(_ group: String) -> Color {
    let normalized = group.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized == "全部" || isDefaultProviderGroup(normalized) {
        return .secondary
    }

    let hash = normalized.unicodeScalars.reduce(5381) { partial, scalar in
        ((partial << 5) &+ partial) &+ Int(scalar.value)
    }
    let hue = Double(abs(hash % 360)) / 360.0
    return Color(
        hue: hue,
        saturation: 0.82,
        brightness: 0.92
    )
}

private enum CCHDateParser {
    static let fractionalISO: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let localDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static var cache: [String: Date] = [:]
    static var cacheOrder: [String] = []

    static func remember(_ date: Date, for key: String) {
        if cache[key] == nil {
            cacheOrder.append(key)
        }
        cache[key] = date

        guard cacheOrder.count > CCHRetentionLimits.parsedDateCache else { return }
        let overflow = cacheOrder.count - CCHRetentionLimits.parsedDateCache
        for key in cacheOrder.prefix(overflow) {
            cache[key] = nil
        }
        cacheOrder.removeFirst(overflow)
    }
}

func parsedCCHDate(_ raw: String) -> Date? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let cached = CCHDateParser.cache[trimmed] {
        return cached
    }

    if let date = CCHDateParser.fractionalISO.date(from: trimmed) {
        CCHDateParser.remember(date, for: trimmed)
        return date
    }

    if let date = CCHDateParser.iso.date(from: trimmed) {
        CCHDateParser.remember(date, for: trimmed)
        return date
    }

    if let date = CCHDateParser.localDateTime.date(from: trimmed) {
        CCHDateParser.remember(date, for: trimmed)
        return date
    }
    return nil
}

func parseCCHDate(_ raw: String) -> Date? {
    parsedCCHDate(raw)
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

func normalizeReleaseVersion(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.lowercased().hasPrefix("v") {
        return String(trimmed.dropFirst())
    }
    return trimmed
}

func compareSemver(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let lhsParts = semverComponents(lhs)
    let rhsParts = semverComponents(rhs)
    let count = max(lhsParts.count, rhsParts.count)
    for index in 0..<count {
        let l = index < lhsParts.count ? lhsParts[index] : 0
        let r = index < rhsParts.count ? rhsParts[index] : 0
        if l < r { return .orderedAscending }
        if l > r { return .orderedDescending }
    }
    return .orderedSame
}

private func semverComponents(_ value: String) -> [Int] {
    let main = value
        .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        .first
        .map(String.init) ?? value
    return main.split(separator: ".").map { Int($0) ?? 0 }
}
