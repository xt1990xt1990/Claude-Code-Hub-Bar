import AppKit
import Combine
import Network
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
    static let maxLoadedLogs = 500
}

private enum CCHProviderModelTestLimits {
    static let maxCustomModels = 8
    static let storageKey = "provider_custom_test_models_v1"
}

enum CCHProviderMiniProbeStatus: String, Codable, Equatable {
    case success
    case warning
    case failure
}

struct CCHProviderMiniProbeSample: Identifiable, Codable, Equatable {
    let createdAt: Date
    let model: String
    let status: CCHProviderMiniProbeStatus
    let latencyMs: Double?
    let ttfbMs: Double?
    let message: String

    var id: String {
        "\(createdAt.timeIntervalSince1970)-\(model)-\(status.rawValue)-\(latencyMs ?? -1)-\(ttfbMs ?? -1)-\(message)"
    }
}

enum CCHProviderMiniProbeLimits {
    static let maxSamples = 8
    static let minAverageSampleCount = 1.0
    static let maxAverageSampleCount = Double(maxSamples)
    static let minIntervalMinutes = 5.0
    static let maxIntervalMinutes = 360.0
    static let maxConcurrentProbes = 4
}

private enum CCHProviderMiniProbeStorage {
    static let selectedProviderIdsKey = "provider_mini_probe_selected_provider_ids_v1"
    static let modelOverridesKey = "provider_mini_probe_model_overrides_v1"
    static let historiesKey = "provider_mini_probe_histories_v1"
}

private enum CCHProviderPinningStorage {
    static let pinnedProviderIdsKey = "provider_pinned_provider_ids_v1"
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
    @AppStorage("active_session_idle_refresh_interval_seconds") var activeSessionIdleRefreshIntervalSeconds = CCHActiveSessionRefreshInterval.defaultIdleSeconds
    @AppStorage("active_session_active_refresh_interval_seconds") var activeSessionActiveRefreshIntervalSeconds = CCHActiveSessionRefreshInterval.defaultActiveSeconds
    @AppStorage("show_status_bar_details") var showStatusBarDetails = true
    @AppStorage("status_bar_reduced_motion") var statusBarReducedMotion = false
    @AppStorage("check_for_updates") var checkForUpdatesEnabled: Bool = true
    @AppStorage("provider_mini_probe_enabled") var providerMiniProbeEnabled = false
    @AppStorage("provider_mini_probe_interval_minutes") var providerMiniProbeIntervalMinutes = 30.0
    @AppStorage("provider_mini_probe_average_ttfb_enabled") var providerMiniProbeAverageTTFBEnabled = true
    @AppStorage("provider_mini_probe_average_sample_count") var providerMiniProbeAverageSampleCount = 8.0
    @AppStorage("provider_mini_probe_schedule_enabled") var providerMiniProbeScheduleEnabled = false
    @AppStorage("provider_mini_probe_schedule_start_hour") var providerMiniProbeScheduleStartHour = 0.0
    @AppStorage("provider_mini_probe_schedule_end_hour") var providerMiniProbeScheduleEndHour = 24.0
    @AppStorage("upstream_rate_auto_sync_enabled") var upstreamRateAutoSyncEnabled = false
    @AppStorage("upstream_rate_auto_sync_interval_hours") var upstreamRateAutoSyncIntervalHours = 6.0
    @AppStorage("upstream_rate_auto_sync_last_run_at") var upstreamRateAutoSyncLastRunEpoch: Double = 0
    @AppStorage("upstream_rate_auto_sync_next_run_at") var upstreamRateAutoSyncNextRunEpoch: Double = 0
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
    @Published var providerSearchText = "" {
        didSet {
            guard providerSearchText != oldValue else { return }
            rebuildProviderFilterSnapshot()
        }
    }
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
    @Published var providers: [CCHProvider] = [] {
        didSet {
            providerStatsSnapshot = CCHProviderStatsBuilder.makeSnapshot(providers: providers)
            providerGroupPresentationCache.removeAll(keepingCapacity: true)
            providerFilterGroupsCache = nil
            assignableProviderGroupsCache = nil
            rebuildProviderIndexes()
        }
    }
    @Published private(set) var assignableProviderGroups: [CCHProviderGroup] = []
    @Published private(set) var providerGroupAssignmentOverrides: [Int: Set<String>] = [:] {
        didSet {
            providerGroupPresentationCache.removeAll(keepingCapacity: true)
            providerFilterGroupsCache = nil
        }
    }
    @Published private(set) var highlightedLogIds: Set<Int> = []
    @Published private(set) var modelTestingProviderIds: Set<Int> = []
    @Published private(set) var providerModelTestResults: [Int: CCHProviderModelTestResult] = [:]
    @Published private(set) var providerModelTestResultsByModel: [Int: [String: CCHProviderModelTestResult]] = [:]
    @Published private(set) var providerModelTestProgress: [Int: CCHProviderModelTestProgress] = [:]
    @Published private(set) var providerCustomTestModels: [Int: [String]] = [:]
    @Published private(set) var pinnedProviderIds: Set<Int> = []
    @Published private(set) var providerMiniProbeSelectedProviderIds: Set<Int> = []
    @Published private(set) var providerMiniProbeModelOverrides: [Int: String] = [:]
    @Published private(set) var providerMiniProbeHistories: [Int: [CCHProviderMiniProbeSample]] = [:] {
        didSet {
            providerMiniProbeAverageTTFBCache.removeAll(keepingCapacity: true)
            providerMiniProbeRecordedSampleTotal = CCHProviderStatsBuilder.miniProbeRecordedSampleCount(providerMiniProbeHistories)
        }
    }
    @Published private(set) var providerMiniProbeRunningIds: Set<Int> = []
    @Published private(set) var providerMultiplierUpdatingIds: Set<Int> = []
    @Published private(set) var upstreamRateSelectedProviderIds: Set<Int> = []
    @Published private(set) var upstreamRateIgnoredHosts: Set<String> = []
    @Published private(set) var upstreamRateSourceTypeOverrides: [String: UpstreamRateSourceType] = [:]
    @Published private(set) var upstreamRateHostDisplayNames: [String: String] = [:]
    @Published private(set) var upstreamRateSnapshots: [UpstreamRateSnapshot] = []
    @Published private(set) var upstreamRateLastCheckedAt: Date?
    @Published private(set) var upstreamRateCredentials: [UpstreamRateCredential] = []
    @Published private(set) var upstreamRateFetchingHosts: Set<String> = []
    @Published private(set) var upstreamRateLastSyncAdjustedProviderIds: Set<Int> = []
    @Published private(set) var upstreamRatePreviousRatesByProviderId: [Int: Double] = [:]
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
    private var providerRowViewModels: [Int: ProviderRowViewModel] = [:]
    private var providerSortState = CCHProviderSortState()
    @Published private(set) var statusBarSnapshot = CCHStatusBarSnapshot(
        showsDetails: true,
        reducedMotion: false,
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
    private var providerMiniProbeTimer: AnyCancellable?
    private var upstreamRateAutoSyncTimer: AnyCancellable?
    private var upstreamBalanceRefreshTimer: AnyCancellable?
    private var upstreamRateSnapshotRefreshSignature = ""
    private var workspaceWakeObservers: [NSObjectProtocol] = []
    private var distributedWakeObservers: [NSObjectProtocol] = []
    private var refreshTask: Task<Void, Never>?
    private var providerMiniProbeResumeTask: Task<Void, Never>?
    private var upstreamWakeRefreshCoordinator = CCHUpstreamWakeRefreshCoordinator()
    private var upstreamWakeRefreshTask: Task<Void, Never>?
    private var providerMiniProbeIntervalRestartTask: Task<Void, Never>?
    private var providerMiniProbeTasks: [Int: Task<Void, Never>] = [:]
    private var providerMiniProbeTaskTokens: [Int: UUID] = [:]
    private var providerMiniProbeRunTokens: [Int: UUID] = [:]
    private var providerMiniProbeHistoriesSaveTask: Task<Void, Never>?
    private var providerMiniProbeLastRunAtByProviderId: [Int: Date] = [:]
    private var providerMiniProbeFailureBackoffUntilByProviderId: [Int: Date] = [:]
    private var providerMiniProbeFailureCountByProviderId: [Int: Int] = [:]
    private let providerMiniProbeNetworkMonitor = NWPathMonitor()
    private let providerMiniProbeNetworkQueue = DispatchQueue(label: "app.cchbar.provider-mini-probe-network")
    private var providerMiniProbeNetworkStatus: NWPath.Status = .requiresConnection
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
    private var activeSessionMenuCache: (sessions: [CCHActiveSession], filter: String, snapshot: CCHActiveSessionMenuSnapshot)?
    private var providerById: [Int: CCHProvider] = [:]
    private var providerMultiplierByName: [String: Double] = [:]
    private var providerMultiplierByProviderId: [Int: Double] = [:]
    private var upstreamProviderInputs: [UpstreamRateProviderInput] = []
    private var upstreamRateSitesCacheInput: CCHUpstreamRateSitesSnapshotInput?
    private var upstreamRateSitesCache: CCHUpstreamRateSitesSnapshot?
    private var cachedMenuBarRunningLogs: [CCHLogEntry] = []
    private var providerStatsSnapshot = CCHProviderStatsSnapshot.empty
    private var providerMiniProbeAverageTTFBCache: [Int: (input: CCHProviderMiniProbeAverageTTFBInput, value: Double?)] = [:]
    private var providerGroupPresentationCache: [Int: (input: CCHProviderGroupPresentationInput, snapshot: CCHProviderGroupPresentationSnapshot)] = [:]
    private var providerFilterGroupsCache: (input: CCHProviderFilterGroupsInput, groups: [String])?
    private var assignableProviderGroupsCache: (input: CCHAssignableProviderGroupsInput, groups: [CCHProviderGroup])?
    private var providerMiniProbeRecordedSampleTotal = 0
    private var refreshTasks: [CCHRefreshKey: CCHRefreshTaskSlot] = [:]
    private var lastSuccessfulRefresh: [CCHRefreshKey: Date] = [:]
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
        activeSessionMenuSnapshot.filteredSessions
    }

    var menuBarActiveSessions: [CCHActiveSession] {
        activeSessionMenuSnapshot.menuBarSessions
    }

    var menuBarRunningLogs: [CCHLogEntry] {
        cachedMenuBarRunningLogs
    }

    var currentMenuBarSession: CCHActiveSession? {
        activeSessionMenuSnapshot.currentMenuBarSession
    }

    private var activeSessionMenuSnapshot: CCHActiveSessionMenuSnapshot {
        if
            let cached = activeSessionMenuCache,
            cached.sessions == activeSessions,
            cached.filter == activeSessionUserFilter
        {
            return cached.snapshot
        }

        let snapshot = CCHActiveSessionMenuBuilder.makeSnapshot(
            from: activeSessions,
            userFilter: activeSessionUserFilter
        )
        activeSessionMenuCache = (activeSessions, activeSessionUserFilter, snapshot)
        return snapshot
    }

    var enabledProviderCount: Int {
        providerStatsSnapshot.enabledCount
    }

    var unhealthyProviderCount: Int {
        providerStatsSnapshot.unhealthyCount
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

    var providerEmptyStateText: String {
        if providerFilterSnapshot.groupProviderCount > 0,
           CCHProviderNameSearch.isActive(providerSearchText) {
            return "没有匹配的渠道"
        }
        return "暂无渠道"
    }

    var upstreamRateSites: [UpstreamRateSite] {
        upstreamRateSitesSnapshot.sites
    }

    var upstreamRateSyncableSites: [UpstreamRateSite] {
        upstreamRateSitesSnapshot.syncableSites
    }

    var upstreamRateNeedsConfigurationSites: [UpstreamRateSite] {
        upstreamRateSitesSnapshot.needsConfigurationSites
    }

    var upstreamRateUnsupportedSites: [UpstreamRateSite] {
        upstreamRateSitesSnapshot.unsupportedSites
    }

    var upstreamRateCheckedSyncCount: Int {
        upstreamRateSitesSnapshot.checkedSyncCount
    }

    var upstreamRatePendingSyncCount: Int {
        upstreamRateSitesSnapshot.pendingSyncCount
    }

    private var upstreamRateSitesSnapshot: CCHUpstreamRateSitesSnapshot {
        let input = CCHUpstreamRateSitesSnapshotInput(
            providers: upstreamProviderInputs,
            snapshots: upstreamRateSnapshots,
            selectedProviderIds: upstreamRateSelectedProviderIds,
            ignoredHosts: upstreamRateIgnoredHosts,
            displayNames: upstreamRateHostDisplayNames,
            lastSyncAdjustedProviderIds: upstreamRateLastSyncAdjustedProviderIds,
            previousUpstreamRatesByProviderId: upstreamRatePreviousRatesByProviderId
        )
        if upstreamRateSitesCacheInput == input, let cached = upstreamRateSitesCache {
            return cached
        }

        let snapshot = CCHUpstreamRateSitesSnapshotBuilder.makeSnapshot(input)
        upstreamRateSitesCacheInput = input
        upstreamRateSitesCache = snapshot
        return snapshot
    }

    func upstreamRateSnapshotsNeedRefresh() -> Bool {
        shouldRefreshUpstreamRateSnapshots(
            providers: upstreamProviderInputs,
            snapshots: upstreamRateSnapshots
        )
    }

    func refreshUpstreamRatesIfSnapshotIsStale() async {
        guard panelVisible, selectedTab == .upstreamRates else { return }
        guard !isRefreshingUpstreamRates else { return }
        let inputs = upstreamProviderInputs
        let signature = upstreamRateProviderSnapshotSignature(providers: inputs)
        guard signature != upstreamRateSnapshotRefreshSignature else { return }
        guard shouldRefreshUpstreamRateSnapshotsOnActivation(
            providers: inputs,
            snapshots: upstreamRateSnapshots
        ) else { return }

        if await refreshUpstreamRates(silent: true) {
            upstreamRateSnapshotRefreshSignature = signature
        }
    }

    var providerMiniProbeSelectedCount: Int {
        providerMiniProbeSelectedProviderIds.count
    }

    var providerMiniProbeRecordedSampleCount: Int {
        providerMiniProbeRecordedSampleTotal
    }

    var providerMiniProbeAverageSampleCountValue: Int {
        Int(min(
            max(providerMiniProbeAverageSampleCount.rounded(), CCHProviderMiniProbeLimits.minAverageSampleCount),
            CCHProviderMiniProbeLimits.maxAverageSampleCount
        ))
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
        pinnedProviderIds = Self.loadIntSet(key: CCHProviderPinningStorage.pinnedProviderIdsKey)
        providerMiniProbeSelectedProviderIds = Self.loadIntSet(key: CCHProviderMiniProbeStorage.selectedProviderIdsKey)
        providerMiniProbeModelOverrides = Self.loadProviderMiniProbeModelOverrides()
        providerMiniProbeHistories = Self.loadProviderMiniProbeHistories()
        providerMiniProbeRecordedSampleTotal = CCHProviderStatsBuilder.miniProbeRecordedSampleCount(providerMiniProbeHistories)
        providerMiniProbeLastRunAtByProviderId = Self.latestProviderMiniProbeRunDates(from: providerMiniProbeHistories)
        upstreamRateSelectedProviderIds = Self.loadIntSet(key: CCHUpstreamRateStorage.selectedProviderIdsKey)
        upstreamRateIgnoredHosts = Self.loadStringSet(key: CCHUpstreamRateStorage.ignoredHostsKey)
        upstreamRateSourceTypeOverrides = Self.loadUpstreamRateSourceTypeOverrides()
        upstreamRateHostDisplayNames = Self.loadUpstreamRateHostDisplayNames()
        upstreamRateSnapshots = Self.loadUpstreamRateSnapshots()
        upstreamRateCredentials = upstreamCredentialStore.load()
        startRefreshTimer()
        startActiveSessionTimer()
        startUpdateCheckTimer()
        startProviderMiniProbeTimer(runImmediately: providerMiniProbeEnabled)
        observeProviderMiniProbeNetwork()
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
        providerMiniProbeTimer?.cancel()
        providerMiniProbeResumeTask?.cancel()
        upstreamWakeRefreshTask?.cancel()
        providerMiniProbeIntervalRestartTask?.cancel()
        providerMiniProbeTasks.values.forEach { $0.cancel() }
        providerMiniProbeNetworkMonitor.cancel()
        upstreamRateAutoSyncTimer?.cancel()
        upstreamBalanceRefreshTimer?.cancel()
        refreshTask?.cancel()
        cacheAlertDismissTask?.cancel()
        simulatedCacheAlertDismissTask?.cancel()
        actionMessageDismissTask?.cancel()
        highlightedLogDismissTasks.values.forEach { $0.cancel() }
        workspaceWakeObservers.forEach {
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        distributedWakeObservers.forEach {
            DistributedNotificationCenter.default().removeObserver($0)
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

    func isProviderHandlingRunningRequest(_ provider: CCHProvider) -> Bool {
        if activeSessions.contains(where: { session in
            session.providerId == provider.id
                && (
                    session.concurrentCount > 0
                    || session.durationMs <= 0
                    || Self.isRunningSessionStatus(session.status)
                )
        }) {
            return true
        }

        let providerName = Self.providerLookupKey(provider.name)
        guard !providerName.isEmpty else { return false }
        return cachedMenuBarRunningLogs.contains { log in
            Self.providerLookupKey(log.providerName) == providerName
        }
    }

    func isProviderGroupSelected(_ group: String) -> Bool {
        group == "全部" ? selectedProviderGroups.isEmpty : selectedProviderGroups.contains(group)
    }

    func toggleProviderGroup(_ group: String) {
        guard group != "全部" else {
            selectedProviderGroups = []
            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                rebuildProviderFilterSnapshot(sortMode: .commitSorted)
            }
            return
        }

        var next = selectedProviderGroups
        if next.contains(group) {
            next.remove(group)
        } else {
            next.insert(group)
        }
        selectedProviderGroups = next
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            rebuildProviderFilterSnapshot(sortMode: .commitSorted)
        }
    }

    func assignedGroupNames(for provider: CCHProvider) -> Set<String> {
        providerGroupPresentationSnapshot(for: provider).assignedGroupNames
    }

    func displayGroupTitles(for provider: CCHProvider) -> [String] {
        providerGroupPresentationSnapshot(for: provider).displayGroupTitles
    }

    private func providerGroupPresentationSnapshot(for provider: CCHProvider) -> CCHProviderGroupPresentationSnapshot {
        let input = CCHProviderGroupPresentationInput(
            providerId: provider.id,
            groupTag: provider.groupTag,
            overrideNames: providerGroupAssignmentOverrides[provider.id]
        )
        if let cached = providerGroupPresentationCache[provider.id], cached.input == input {
            return cached.snapshot
        }

        let snapshot = CCHProviderGroupPresentationBuilder.makeSnapshot(input)
        providerGroupPresentationCache[provider.id] = (input, snapshot)
        return snapshot
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

    func setActiveSessionIdleRefreshIntervalSeconds(_ seconds: Int) {
        activeSessionIdleRefreshIntervalSeconds = CCHActiveSessionRefreshInterval.sanitizedIdleSeconds(seconds)
    }

    func setActiveSessionActiveRefreshIntervalSeconds(_ seconds: Int) {
        activeSessionActiveRefreshIntervalSeconds = CCHActiveSessionRefreshInterval.sanitizedActiveSeconds(seconds)
    }

    func setPanelVisible(_ visible: Bool) {
        guard panelVisible != visible else { return }
        panelVisible = visible
        if visible {
            startFocusedViewTimer()
            Task { await refreshFocusedView(commitProviderSort: selectedTab == .providers) }
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

    func refresh(commitProviderSort: Bool = false, force: Bool = true) async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil

        async let overviewResult = runRefresh(.overview, force: force) { await self.loadOverview() }
        async let sessionsResult = runRefresh(.activeSessions, force: force) { await self.loadActiveSessions() }
        async let leaderboardResult = runRefresh(.leaderboard, force: force) { await self.loadLeaderboard() }
        async let logsResult = runRefresh(.logs(includeStats: true), force: force) { await self.loadLogs(includeStats: true) }
        async let providersResult = runRefresh(.providers(usage: true), force: force) {
            await self.loadProviders(includeUsage: true, sortMode: commitProviderSort ? .commitSorted : .preserveCurrentOrder)
        }

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
        errorMessage = await runRefresh(.logs(includeStats: true), force: true) {
            await self.loadLogs(reset: true, includeStats: true)
        }
        lastRefresh = Date()
        isLoading = false
    }

    func loadMoreLogs() async {
        guard !isLoadingMoreLogs, logs.count < logTotal || logTotal == 0 else { return }
        isLoadingMoreLogs = true
        errorMessage = await runRefresh(.logs(includeStats: false), force: true) {
            await self.loadLogs(reset: false, includeStats: false)
        }
        lastRefresh = Date()
        isLoadingMoreLogs = false
    }

    func refreshLeaderboardOnly() async {
        isLoading = true
        errorMessage = await runRefresh(.leaderboard, force: true) { await self.loadLeaderboard() }
        lastRefresh = Date()
        isLoading = false
    }

    func refreshFocusedView(commitProviderSort: Bool = false) async {
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
            error = await runRefresh(.providers(usage: true)) {
                await self.loadProviders(includeUsage: true, sortMode: commitProviderSort ? .commitSorted : .preserveCurrentOrder)
            }
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

        async let sessionsError = runRefresh(.activeSessions, force: true) { await self.loadActiveSessions() }
        async let overviewError = runRefresh(.overview, force: true) { await self.loadOverview() }
        async let recentLogsError = runRefresh(.recentLogs, force: true) { await self.loadRecentLogsForStatusBar() }

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

        if let recentLogsError = await runRefresh(
            .recentLogs,
            force: true,
            operation: { await self.loadRecentLogsForStatusBar() }
        ) {
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

    func isProviderMiniProbeEnabled(_ provider: CCHProvider) -> Bool {
        providerMiniProbeSelectedProviderIds.contains(provider.id)
    }

    func isProviderPinned(_ provider: CCHProvider) -> Bool {
        pinnedProviderIds.contains(provider.id)
    }

    func toggleProviderPinned(_ provider: CCHProvider) {
        if pinnedProviderIds.contains(provider.id) {
            pinnedProviderIds.remove(provider.id)
        } else {
            pinnedProviderIds.insert(provider.id)
        }
        savePinnedProviderIds()
        rebuildProviderFilterSnapshot(sortMode: .commitSorted)
    }

    func isProviderMiniProbeRunning(_ provider: CCHProvider) -> Bool {
        providerMiniProbeRunningIds.contains(provider.id)
    }

    func providerMiniProbeHistory(for provider: CCHProvider) -> [CCHProviderMiniProbeSample] {
        providerMiniProbeHistories[provider.id] ?? []
    }

    func providerMiniProbeAverageTTFB(for provider: CCHProvider) -> Double? {
        let input = CCHProviderMiniProbeAverageTTFBInput(
            isEnabled: providerMiniProbeAverageTTFBEnabled,
            maxCount: providerMiniProbeAverageSampleCountValue,
            samples: providerMiniProbeHistory(for: provider)
        )
        if let cached = providerMiniProbeAverageTTFBCache[provider.id], cached.input == input {
            return cached.value
        }

        let value = CCHProviderMiniProbeMetricsBuilder.averageTTFB(input)
        providerMiniProbeAverageTTFBCache[provider.id] = (input, value)
        return value
    }

    func providerMiniProbeModel(for provider: CCHProvider) -> String {
        providerMiniProbeModelOverrides[provider.id] ?? ""
    }

    func resolvedProviderMiniProbeModelTitle(for provider: CCHProvider) -> String {
        resolvedProviderMiniProbeModel(for: provider)
    }

    func setProviderMiniProbeModel(_ model: String, for provider: CCHProvider) {
        let normalized = normalizedProviderTestModel(model)
        if normalized.isEmpty {
            providerMiniProbeModelOverrides.removeValue(forKey: provider.id)
            flashActionMessage("已恢复默认探针模型 \(provider.name)")
        } else {
            providerMiniProbeModelOverrides[provider.id] = normalized
            flashActionMessage("已设置探针模型 \(provider.name): \(normalized)")
        }
        saveProviderMiniProbeModelOverrides()
    }

    func setProviderMiniProbe(_ provider: CCHProvider, enabled: Bool) {
        if enabled {
            providerMiniProbeSelectedProviderIds.insert(provider.id)
            if providerMiniProbeEnabled, !isProviderMiniProbeWithinSchedule() {
                flashActionMessage("已开启探针 \(provider.name)，当前不在运行时段", duration: 4, isWarning: true)
            } else {
                flashActionMessage("已开启探针 \(provider.name)")
            }
        } else {
            providerMiniProbeSelectedProviderIds.remove(provider.id)
            providerMiniProbeTasks[provider.id]?.cancel()
            providerMiniProbeTasks[provider.id] = nil
            providerMiniProbeTaskTokens[provider.id] = nil
            providerMiniProbeRunTokens[provider.id] = nil
            providerMiniProbeRunningIds.remove(provider.id)
            flashActionMessage("已关闭探针 \(provider.name)")
        }
        saveProviderMiniProbeSelectedProviderIds()
        rebuildProviderFilterSnapshot()

        guard enabled, providerMiniProbeEnabled else { return }
        startProviderMiniProbeTask(provider, silent: true, respectingInterval: false)
    }

    func normalizeProviderMiniProbeInterval() {
        let normalized = min(
            max(providerMiniProbeIntervalMinutes, CCHProviderMiniProbeLimits.minIntervalMinutes),
            CCHProviderMiniProbeLimits.maxIntervalMinutes
        )
        if abs(providerMiniProbeIntervalMinutes - normalized) > 0.001 {
            providerMiniProbeIntervalMinutes = normalized
        }
    }

    func normalizeProviderMiniProbeAverageSampleCount() {
        let normalized = min(
            max(providerMiniProbeAverageSampleCount.rounded(), CCHProviderMiniProbeLimits.minAverageSampleCount),
            CCHProviderMiniProbeLimits.maxAverageSampleCount
        )
        if abs(providerMiniProbeAverageSampleCount - normalized) > 0.001 {
            providerMiniProbeAverageSampleCount = normalized
        }
    }

    func restartProviderMiniProbeTimerDebounced() {
        providerMiniProbeIntervalRestartTask?.cancel()
        providerMiniProbeIntervalRestartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self, !Task.isCancelled else { return }
            self.startProviderMiniProbeTimer()
            self.providerMiniProbeIntervalRestartTask = nil
        }
    }

    func normalizeProviderMiniProbeSchedule() {
        let normalizedStart = min(max(providerMiniProbeScheduleStartHour, 0), 24)
        let normalizedEnd = min(max(providerMiniProbeScheduleEndHour, 0), 24)
        if abs(providerMiniProbeScheduleStartHour - normalizedStart) > 0.001 {
            providerMiniProbeScheduleStartHour = normalizedStart
        }
        if abs(providerMiniProbeScheduleEndHour - normalizedEnd) > 0.001 {
            providerMiniProbeScheduleEndHour = normalizedEnd
        }
    }

    func providerMiniProbeScheduleText() -> String {
        guard providerMiniProbeScheduleEnabled else { return "全天" }
        let start = min(max(providerMiniProbeScheduleStartHour, 0), 24)
        let end = min(max(providerMiniProbeScheduleEndHour, 0), 24)
        if start <= 0, end >= 24 {
            return "全天"
        }
        if abs(start - end) < 0.001 {
            return "已停用"
        }
        let suffix = start > end ? " 次日" : ""
        return "\(formatProviderMiniProbeHour(start))-\(formatProviderMiniProbeHour(end))\(suffix)"
    }

    func isProviderMiniProbeWithinSchedule(now: Date = Date()) -> Bool {
        guard providerMiniProbeScheduleEnabled else { return true }
        normalizeProviderMiniProbeSchedule()
        let start = providerMiniProbeScheduleStartHour
        let end = providerMiniProbeScheduleEndHour
        if start <= 0, end >= 24 { return true }
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let hour = Double(components.hour ?? 0)
            + Double(components.minute ?? 0) / 60
            + Double(components.second ?? 0) / 3600
        if start < end {
            return hour >= start && hour < end
        }
        if start > end {
            return hour >= start || hour < end
        }
        return false
    }

    func startProviderMiniProbeTimer(runImmediately: Bool = false, forceImmediate: Bool = false) {
        providerMiniProbeTimer?.cancel()
        guard providerMiniProbeEnabled else {
            providerMiniProbeTimer = nil
            return
        }

        normalizeProviderMiniProbeInterval()
        let interval = providerMiniProbeIntervalMinutes * 60
        providerMiniProbeTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.runScheduledProviderMiniProbes(respectingInterval: true) }
            }

        if runImmediately {
            Task { await runScheduledProviderMiniProbes(respectingInterval: !forceImmediate) }
        }
    }

    func runScheduledProviderMiniProbes(respectingInterval: Bool = true) async {
        guard providerMiniProbeEnabled else { return }
        guard isProviderMiniProbeWithinSchedule() else { return }
        guard !providerMiniProbeSelectedProviderIds.isEmpty else { return }

        if providers.isEmpty {
            _ = await loadProviders(includeUsage: false)
        }

        let selectedIds = providerMiniProbeSelectedProviderIds
        let targets = providers
            .filter { selectedIds.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let dueTargets = respectingInterval
            ? targets.filter { isProviderMiniProbeDue(providerId: $0.id) }
            : targets
        guard !dueTargets.isEmpty else { return }

        var iterator = dueTargets.makeIterator()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<min(CCHProviderMiniProbeLimits.maxConcurrentProbes, dueTargets.count) {
                guard let provider = iterator.next() else { break }
                group.addTask { @MainActor in
                    await self.runProviderMiniProbe(provider, silent: true, respectingInterval: false)
                }
            }
            while await group.next() != nil {
                guard let provider = iterator.next() else { continue }
                group.addTask { @MainActor in
                    await self.runProviderMiniProbe(provider, silent: true, respectingInterval: false)
                }
            }
        }
    }

    func runProviderMiniProbe(_ provider: CCHProvider, silent: Bool = true, respectingInterval: Bool = false) async {
        guard providerMiniProbeEnabled else { return }
        guard isProviderMiniProbeWithinSchedule() else { return }
        guard providerMiniProbeSelectedProviderIds.contains(provider.id) else { return }
        guard providerMiniProbeNetworkStatus == .satisfied else { return }
        if respectingInterval {
            guard isProviderMiniProbeDue(providerId: provider.id) else { return }
        }
        guard !providerMiniProbeRunningIds.contains(provider.id) else { return }
        guard !modelTestingProviderIds.contains(provider.id) else { return }

        let runToken = UUID()
        providerMiniProbeRunTokens[provider.id] = runToken
        providerMiniProbeRunningIds.insert(provider.id)
        defer {
            if providerMiniProbeRunTokens[provider.id] == runToken {
                providerMiniProbeRunTokens[provider.id] = nil
                providerMiniProbeRunningIds.remove(provider.id)
            }
        }

        let testModel = resolvedProviderMiniProbeModel(for: provider)
        do {
            let result = try await api.testProviderModel(config: config, provider: provider, model: testModel)
            guard shouldRecordProviderMiniProbeResult(providerId: provider.id, runToken: runToken) else { return }
            appendProviderMiniProbeSample(providerId: provider.id, sample: miniProbeSample(from: result, requestedModel: testModel))
        } catch {
            guard shouldRecordProviderMiniProbeResult(providerId: provider.id, runToken: runToken) else { return }
            appendProviderMiniProbeSample(
                providerId: provider.id,
                sample: CCHProviderMiniProbeSample(
                    createdAt: Date(),
                    model: testModel,
                    status: .failure,
                    latencyMs: nil,
                    ttfbMs: nil,
                    message: error.localizedDescription
                )
            )
            if !silent {
                flashActionMessage("探针 \(provider.name): \(error.localizedDescription)", duration: 5, isWarning: true)
            }
        }
    }

    private func shouldRecordProviderMiniProbeResult(providerId: Int, runToken: UUID) -> Bool {
        !Task.isCancelled
            && providerMiniProbeRunTokens[providerId] == runToken
            && providerMiniProbeSelectedProviderIds.contains(providerId)
    }

    private func startProviderMiniProbeTask(
        _ provider: CCHProvider,
        silent: Bool,
        respectingInterval: Bool
    ) {
        providerMiniProbeTasks[provider.id]?.cancel()
        let providerId = provider.id
        let taskToken = UUID()
        providerMiniProbeTaskTokens[providerId] = taskToken
        providerMiniProbeTasks[providerId] = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runProviderMiniProbe(provider, silent: silent, respectingInterval: respectingInterval)
            if self.providerMiniProbeTaskTokens[providerId] == taskToken {
                self.providerMiniProbeTaskTokens[providerId] = nil
                self.providerMiniProbeTasks[providerId] = nil
            }
        }
    }

    private func runProviderMiniProbesAfterSystemResumeIfNeeded() {
        guard providerMiniProbeEnabled else { return }
        guard isProviderMiniProbeWithinSchedule() else { return }
        guard !providerMiniProbeSelectedProviderIds.isEmpty else { return }
        guard providerMiniProbeNetworkStatus == .satisfied else { return }
        let now = Date()
        guard providerMiniProbeSelectedProviderIds.contains(where: { isProviderMiniProbeDue(providerId: $0, now: now) }) else {
            return
        }

        providerMiniProbeResumeTask?.cancel()
        providerMiniProbeResumeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self else { return }
            await self.runScheduledProviderMiniProbes(respectingInterval: true)
            self.providerMiniProbeResumeTask = nil
        }
    }

    private func observeProviderMiniProbeNetwork() {
        providerMiniProbeNetworkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let oldStatus = self.providerMiniProbeNetworkStatus
                self.providerMiniProbeNetworkStatus = path.status
                if oldStatus != .satisfied, path.status == .satisfied {
                    self.runProviderMiniProbesAfterSystemResumeIfNeeded()
                    self.runUpstreamBalanceRefreshAfterNetworkRestoredIfNeeded()
                } else if oldStatus == .satisfied, path.status != .satisfied {
                    self.upstreamWakeRefreshCoordinator.networkDidBecomeUnsatisfied()
                }
            }
        }
        providerMiniProbeNetworkMonitor.start(queue: providerMiniProbeNetworkQueue)
    }

    private func isProviderMiniProbeDue(providerId: Int, now: Date = Date()) -> Bool {
        normalizeProviderMiniProbeInterval()
        if let backoffUntil = providerMiniProbeFailureBackoffUntilByProviderId[providerId], now < backoffUntil {
            return false
        }
        return providerMiniProbeIsDue(
            lastRunAt: latestProviderMiniProbeRunDate(providerId: providerId),
            intervalMinutes: providerMiniProbeIntervalMinutes,
            now: now
        )
    }

    private func latestProviderMiniProbeRunDate(providerId: Int) -> Date? {
        if let lastRun = providerMiniProbeLastRunAtByProviderId[providerId] {
            return lastRun
        }
        return providerMiniProbeHistories[providerId]?.map(\.createdAt).max()
    }

    func isProviderMultiplierUpdating(_ provider: CCHProvider) -> Bool {
        providerMultiplierUpdatingIds.contains(provider.id)
    }

    func isProviderDispatchSettingsUpdating(_ provider: CCHProvider) -> Bool {
        providerMultiplierUpdatingIds.contains(provider.id)
    }

    func isUpstreamRateProviderUpdating(_ providerId: Int) -> Bool {
        providerMultiplierUpdatingIds.contains(providerId)
    }

    func provider(forUpstreamRateRow row: UpstreamRateProviderRow) -> CCHProvider? {
        providerById[row.providerId]
    }

    func toggleUpstreamRateSyncSelection(_ row: UpstreamRateProviderRow) async {
        guard row.isSelectableForSync else { return }
        if upstreamRateSelectedProviderIds.contains(row.providerId) {
            upstreamRateSelectedProviderIds.remove(row.providerId)
            saveUpstreamRateSelectedProviderIds()
            return
        }

        upstreamRateSelectedProviderIds.insert(row.providerId)
        saveUpstreamRateSelectedProviderIds()

        if row.shouldRefreshSnapshotOnSyncSelection {
            await refreshUpstreamRates(silent: true)
        } else if row.hasRateChange {
            await syncUpstreamRate(row, showNoopMessage: false)
        }
    }

    @discardableResult
    func refreshUpstreamRates(silent: Bool = false) async -> Bool {
        if isRefreshingUpstreamRates || isRefreshingUpstreamBalances { return false }
        isRefreshingUpstreamRates = true
        defer { isRefreshingUpstreamRates = false }

        if providers.isEmpty {
            _ = await loadProviders(includeUsage: true)
        }

        let credentialsByHost = Dictionary(uniqueKeysWithValues: upstreamRateCredentials.map { ($0.host, $0) })
        let grouped = Dictionary(grouping: upstreamProviderInputs) { input in
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
        let sortedNextCredentials = nextCredentials.sorted { $0.host < $1.host }
        if sortedNextCredentials != upstreamRateCredentials {
            upstreamRateCredentials = sortedNextCredentials
            do {
                try upstreamCredentialStore.save(upstreamRateCredentials)
            } catch {
                flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
            }
        }
        let activeHosts = Set(sortedGroups.map(\.key))
        let previousSnapshots = upstreamRateSnapshots
        let mergedSnapshots = UpstreamRateSnapshot
            .mergeLatest(cached: upstreamRateSnapshots, refreshed: nextSnapshots)
            .filter { activeHosts.contains($0.host) }
        if upstreamRateSnapshots != mergedSnapshots {
            upstreamRateSnapshots = mergedSnapshots
        }
        let nextPreviousRates = changedPreviousUpstreamRatesByProviderId(
            previousSnapshots: previousSnapshots,
            currentSnapshots: mergedSnapshots
        )
        if upstreamRatePreviousRatesByProviderId != nextPreviousRates {
            upstreamRatePreviousRatesByProviderId = nextPreviousRates
        }
        if upstreamRateSnapshots != previousSnapshots {
            saveUpstreamRateSnapshots()
        }
        upstreamRateLastCheckedAt = Date()

        let preSyncMultipliers = providerMultiplierByProviderId
        await syncSelectedUpstreamRates(showEmptyMessage: false)
        let nextAdjustedProviderIds = Set<Int>(
            providers.compactMap { provider in
                guard let previous = preSyncMultipliers[provider.id] else { return nil }
                return abs(provider.costMultiplier - previous) > 0.0001 ? provider.id : nil
            }
        )
        if upstreamRateLastSyncAdjustedProviderIds != nextAdjustedProviderIds {
            upstreamRateLastSyncAdjustedProviderIds = nextAdjustedProviderIds
        }

        if !silent {
            flashActionMessage("上游倍率已检测")
        }
        return true
    }

    func refreshUpstreamBalances(silent: Bool = false, onlyIfStale: Bool = false) async {
        if isRefreshingUpstreamBalances || isRefreshingUpstreamRates { return }
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
                    } catch let error as UpstreamRateServiceError where error.isAuthenticationExpired {
                        return UpstreamRateHostRefreshResult(
                            host: credential.host,
                            snapshot: UpstreamRateSnapshot(host: credential.host, sourceType: credential.sourceType, status: .authExpired),
                            credential: nil,
                            errorMessage: error.localizedDescription
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
            } else if let snapshot = result.snapshot, snapshot.status == .authExpired {
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

        let sortedNextCredentials = nextCredentials.sorted { $0.host < $1.host }
        if sortedNextCredentials != upstreamRateCredentials {
            upstreamRateCredentials = sortedNextCredentials
            do {
                try upstreamCredentialStore.save(upstreamRateCredentials)
            } catch {
                flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
            }
        }
        if !balanceSnapshots.isEmpty {
            let authExpiredSnapshots = balanceSnapshots.filter { $0.status == .authExpired }
            let authMergedSnapshots = UpstreamRateSnapshot.mergeLatest(
                cached: upstreamRateSnapshots,
                refreshed: authExpiredSnapshots
            )
            let mergedSnapshots = UpstreamRateSnapshot.mergeBalances(
                cached: authMergedSnapshots,
                balances: balanceSnapshots.filter { $0.balance != nil }
            )
            let didChangeSnapshots = upstreamRateSnapshots != mergedSnapshots
            if didChangeSnapshots {
                upstreamRateSnapshots = mergedSnapshots
                saveUpstreamRateSnapshots()
            }
        }
        let completedHostCount = results.lazy.filter { $0.snapshot != nil }.count
        if shouldRecordUpstreamBalanceRefreshSuccess(
            totalHostCount: results.count,
            completedHostCount: completedHostCount
        ) {
            upstreamBalanceLastRefreshedAt = Date()
        }
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
            } catch let error as UpstreamRateServiceError where error.isAuthenticationExpired {
                return UpstreamRateHostRefreshResult(
                    host: host,
                    snapshot: UpstreamRateSnapshot(host: host, sourceType: credential.sourceType, status: .authExpired),
                    credential: nil,
                    errorMessage: error.localizedDescription
                )
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

    func startUpstreamRateAutoSyncTimer(resetSchedule: Bool = false) {
        upstreamRateAutoSyncTimer?.cancel()
        guard upstreamRateAutoSyncEnabled else {
            upstreamRateAutoSyncTimer = nil
            upstreamRateAutoSyncNextRunEpoch = 0
            return
        }
        let hours = UpstreamRateAutoSyncTiming.clampedIntervalHours(upstreamRateAutoSyncIntervalHours)
        if hours != upstreamRateAutoSyncIntervalHours {
            upstreamRateAutoSyncIntervalHours = hours
        }
        if resetSchedule {
            upstreamRateAutoSyncNextRunEpoch = 0
        }
        upstreamRateAutoSyncNextRunEpoch = UpstreamRateAutoSyncTiming.nextRunEpoch(
            now: Date(),
            intervalHours: hours,
            existingNextRunEpoch: upstreamRateAutoSyncNextRunEpoch
        )
        upstreamRateAutoSyncTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.runDueUpstreamRateAutoSyncIfNeeded()
            }
        runDueUpstreamRateAutoSyncIfNeeded()
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
        let startedAt = Date()
        let didRun = await refreshUpstreamRates(silent: true)
        guard didRun else { return }
        upstreamRateAutoSyncLastRunEpoch = startedAt.timeIntervalSince1970
        upstreamRateAutoSyncNextRunEpoch = Date()
            .addingTimeInterval(UpstreamRateAutoSyncTiming.intervalSeconds(hours: upstreamRateAutoSyncIntervalHours))
            .timeIntervalSince1970
    }

    func runDueUpstreamRateAutoSyncIfNeeded(now: Date = Date()) {
        guard upstreamRateAutoSyncEnabled else { return }
        guard UpstreamRateAutoSyncTiming.shouldRun(now: now, nextRunEpoch: upstreamRateAutoSyncNextRunEpoch) else { return }
        Task { await self.runScheduledUpstreamRateAutoSync() }
    }

    var upstreamRateAutoSyncLastRunAt: Date? {
        upstreamRateAutoSyncLastRunEpoch > 0
            ? Date(timeIntervalSince1970: upstreamRateAutoSyncLastRunEpoch)
            : nil
    }

    var upstreamRateAutoSyncNextRunAt: Date? {
        guard upstreamRateAutoSyncEnabled, upstreamRateAutoSyncNextRunEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: upstreamRateAutoSyncNextRunEpoch)
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

    func updateProviderDispatchSettings(_ provider: CCHProvider, settings: CCHProviderDispatchSettings) async {
        if providerMultiplierUpdatingIds.contains(provider.id) {
            return
        }

        actionMessageDismissTask?.cancel()
        actionMessage = "更新调度 \(provider.name): 优先级 \(settings.priority) · 权重 \(settings.weight)..."
        actionMessageIsWarning = false
        providerMultiplierUpdatingIds.insert(provider.id)
        defer {
            providerMultiplierUpdatingIds.remove(provider.id)
        }

        do {
            try await api.setProviderDispatchSettings(config: config, providerId: provider.id, settings: settings)
            flashActionMessage("调度已更新 \(provider.name): 优先级 \(settings.priority) · 权重 \(settings.weight)")
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
                    ttfbMs: nil,
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
            let latency = formatProviderModelTestTiming(result)
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

    private func resolvedProviderMiniProbeModel(for provider: CCHProvider) -> String {
        if let providerModel = providerMiniProbeModelOverrides[provider.id],
           !providerModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return providerModel
        }
        return provider.testModel
    }

    private func miniProbeSample(
        from result: CCHProviderModelTestResult,
        requestedModel: String
    ) -> CCHProviderMiniProbeSample {
        let status = providerMiniProbeStatus(from: result)
        let detail = result.errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? result.message
            : result.errorMessage
        return CCHProviderMiniProbeSample(
            createdAt: Date(),
            model: result.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? requestedModel : result.model,
            status: status,
            latencyMs: result.latencyMs,
            ttfbMs: providerMiniProbeSuccessTTFBMs(isSuccess: status == .success, ttfbMs: result.ttfbMs),
            message: detail
        )
    }

    private func providerMiniProbeStatus(from result: CCHProviderModelTestResult) -> CCHProviderMiniProbeStatus {
        let status = result.status.lowercased()
        if result.success || status == "green" { return .success }
        if status == "yellow" { return .warning }
        return .failure
    }

    private func appendProviderMiniProbeSample(providerId: Int, sample: CCHProviderMiniProbeSample) {
        var samples = providerMiniProbeHistories[providerId] ?? []
        samples.append(sample)
        providerMiniProbeHistories[providerId] = Array(samples.suffix(CCHProviderMiniProbeLimits.maxSamples))
        switch sample.status {
        case .success, .warning:
            providerMiniProbeLastRunAtByProviderId[providerId] = sample.createdAt
            providerMiniProbeFailureBackoffUntilByProviderId[providerId] = nil
            providerMiniProbeFailureCountByProviderId[providerId] = 0
        case .failure:
            let failureCount = (providerMiniProbeFailureCountByProviderId[providerId] ?? 0) + 1
            providerMiniProbeFailureCountByProviderId[providerId] = failureCount
            providerMiniProbeFailureBackoffUntilByProviderId[providerId] = sample.createdAt.addingTimeInterval(
                providerMiniProbeFailureBackoffSeconds(
                    failureCount: failureCount,
                    intervalMinutes: providerMiniProbeIntervalMinutes
                )
            )
        }
        saveProviderMiniProbeHistoriesDebounced()
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
        force: Bool = false,
        operation: @escaping @MainActor () async -> String?
    ) async -> String? {
        if let slot = refreshTasks[key] {
            return await slot.task.value
        }

        let now = Date()
        let freshness = CCHRefreshFreshnessPolicy(ttl: refreshTTL(for: key, now: now))
        if !freshness.shouldRefresh(lastSuccessful: lastSuccessfulRefresh[key], now: now, force: force) {
            return nil
        }

        let id = UUID()
        let task = Task { @MainActor in
            await operation()
        }
        refreshTasks[key] = CCHRefreshTaskSlot(id: id, task: task)
        let result = await task.value
        if result == nil {
            lastSuccessfulRefresh[key] = Date()
        }
        if refreshTasks[key]?.id == id {
            refreshTasks[key] = nil
        }
        return result
    }

    private func refreshTTL(for key: CCHRefreshKey, now: Date) -> TimeInterval {
        switch key {
        case .overview:
            return panelVisible || !cachedMenuBarRunningLogs.isEmpty ? 3 : 15
        case .activeSessions:
            return panelVisible ? 5 : 15
        case .recentLogs:
            return statusBarPollingPolicy.dataRefreshInterval(
                hasRunningItems: !cachedMenuBarRunningLogs.isEmpty,
                lastRunningSeenAt: lastStatusBarRunningSeenAt,
                idleInterval: CCHActiveSessionRefreshInterval.idleTimeInterval(
                    seconds: activeSessionIdleRefreshIntervalSeconds
                ),
                activeInterval: CCHActiveSessionRefreshInterval.activeTimeInterval(
                    seconds: activeSessionActiveRefreshIntervalSeconds
                ),
                now: now
            )
        case .logs(let includeStats):
            return includeStats ? 15 : 3
        case .leaderboard:
            return panelVisible ? 15 : 30
        case .providers(let usage):
            return usage ? (panelVisible ? 5 : 30) : 30
        }
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
            idleInterval: CCHActiveSessionRefreshInterval.idleTimeInterval(seconds: activeSessionIdleRefreshIntervalSeconds),
            activeInterval: CCHActiveSessionRefreshInterval.activeTimeInterval(seconds: activeSessionActiveRefreshIntervalSeconds),
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
            guard recentLogs != page.logs else {
                lastStatusBarDataRefresh = Date()
                return nil
            }

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
                if logs.count > CCHRetentionLimits.maxLoadedLogs {
                    logs = Array(logs.suffix(CCHRetentionLimits.maxLoadedLogs))
                }
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

    private func loadProviders(
        includeUsage: Bool = true,
        sortMode: CCHProviderSortMode = .preserveCurrentOrder
    ) async -> String? {
        do {
            providers = try await api.fetchProviders(config: config, includeUsage: includeUsage)
            if shouldRefreshProviderGroups() {
                if let groups = try? await api.fetchProviderGroups(config: config) {
                    officialProviderGroups = groups
                    lastProviderGroupsRefresh = Date()
                }
            }
            let nextAssignableGroups = mergedAssignableProviderGroups(officialProviderGroups)
            if assignableProviderGroups != nextAssignableGroups {
                assignableProviderGroups = nextAssignableGroups
            }
            if includeUsage {
                lastProviderUsageRefresh = Date()
            }
            reconcileProviderGroupAssignmentOverrides()
            rebuildProviderLookup()
            let allGroups = computedProviderGroups()
            selectedProviderGroups = selectedProviderGroups.intersection(Set(allGroups))
            rebuildProviderFilterSnapshot(groups: allGroups, sortMode: sortMode)
            updateStatusBarSnapshot()
            if panelVisible, selectedTab == .upstreamRates {
                Task { await refreshUpstreamRatesIfSnapshotIsStale() }
            }
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
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification
        ] {
            let observer = workspaceCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.refresh(force: false)
                    self.runProviderMiniProbesAfterSystemResumeIfNeeded()
                    self.runDueUpstreamRateAutoSyncIfNeeded()
                    self.runUpstreamBalanceRefreshAfterSystemResumeIfNeeded()
                }
            }
            workspaceWakeObservers.append(observer)
        }

        let unlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.runProviderMiniProbesAfterSystemResumeIfNeeded()
                self.runDueUpstreamRateAutoSyncIfNeeded()
            }
        }
        distributedWakeObservers.append(unlockObserver)
    }

    private func runUpstreamBalanceRefreshAfterSystemResumeIfNeeded() {
        let shouldSchedule = upstreamWakeRefreshCoordinator.systemDidWake(
            networkIsSatisfied: providerMiniProbeNetworkStatus == .satisfied
        )
        guard shouldSchedule else { return }
        scheduleUpstreamBalanceRefreshAfterSystemResume()
    }

    private func runUpstreamBalanceRefreshAfterNetworkRestoredIfNeeded() {
        guard upstreamWakeRefreshCoordinator.networkDidBecomeSatisfied() else { return }
        scheduleUpstreamBalanceRefreshAfterSystemResume()
    }

    private func scheduleUpstreamBalanceRefreshAfterSystemResume() {
        guard upstreamWakeRefreshTask == nil else { return }
        upstreamWakeRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: CCHUpstreamWakeRefreshCoordinator.networkSettleDelayNanoseconds
                )
                guard !Task.isCancelled else { return }

                while self.upstreamWakeRefreshCoordinator.shouldWaitForUpstreamOperation(
                    rateRefreshIsRunning: self.isRefreshingUpstreamRates,
                    balanceRefreshIsRunning: self.isRefreshingUpstreamBalances
                ) {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    guard !Task.isCancelled else { return }
                }

                guard self.upstreamWakeRefreshCoordinator.scheduledRefreshCanStart(
                    networkIsSatisfied: self.providerMiniProbeNetworkStatus == .satisfied
                ) else {
                    self.upstreamWakeRefreshTask = nil
                    return
                }

                await self.refreshUpstreamBalances(silent: true)
                let shouldRepeat = self.upstreamWakeRefreshCoordinator.refreshDidFinish(
                    networkIsSatisfied: self.providerMiniProbeNetworkStatus == .satisfied
                )
                guard shouldRepeat else {
                    self.upstreamWakeRefreshTask = nil
                    return
                }
            }
        }
    }

    private func rebuildCacheStatus() {
        let snapshot = CCHCacheStatusMapBuilder.makeSnapshot(
            recentLogs: recentLogs,
            logs: logs,
            history: recentLogHistory
        )
        if cacheStatusByLogId != snapshot.statusByLogId {
            cacheStatusByLogId = snapshot.statusByLogId
        }
        rebuildMenuBarRunningLogs()
        announceLatestCacheAlert(logId: snapshot.latestRebuildingLogId)
        updateStatusBarSnapshot()
    }

    private func rebuildProviderLookup() {
        rebuildProviderIndexes()
        pruneUpstreamRateSelections()
        pruneProviderMiniProbeData()
        reconcileProviderRowViewModels()
    }

    private func rebuildProviderIndexes() {
        providerById = Dictionary(
            providers.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        providerMultiplierByName = Dictionary(
            providers.map { ($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0.costMultiplier) },
            uniquingKeysWith: { current, _ in current }
        )
        providerMultiplierByProviderId = Dictionary(
            providers.map { ($0.id, $0.costMultiplier) },
            uniquingKeysWith: { current, _ in current }
        )
        upstreamProviderInputs = providers.map(upstreamProviderInput)
    }

    private static func providerLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isRunningSessionStatus(_ status: String) -> Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return false }
        return normalized.contains("active")
            || normalized.contains("running")
            || normalized.contains("progress")
            || normalized.contains("request")
            || normalized.contains("retry")
            || normalized.contains("请求")
    }

    private func reconcileProviderRowViewModels() {
        let currentIds = Set(providers.map(\.id))
        for staleId in providerRowViewModels.keys where !currentIds.contains(staleId) {
            providerRowViewModels.removeValue(forKey: staleId)
        }
        for provider in providers where providerRowViewModels[provider.id] == nil {
            providerRowViewModels[provider.id] = ProviderRowViewModel(provider: provider, state: self)
        }
    }

    func providerRowViewModel(for provider: CCHProvider) -> ProviderRowViewModel {
        if let existing = providerRowViewModels[provider.id] {
            return existing
        }
        let model = ProviderRowViewModel(provider: provider, state: self)
        providerRowViewModels[provider.id] = model
        return model
    }

    func commitProviderSortIfNeeded() {
        guard selectedTab == .providers, providerSortState.hasPendingSort else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            rebuildProviderFilterSnapshot(sortMode: .commitSorted)
        }
    }

    private func computedProviderGroups() -> [String] {
        let input = CCHProviderFilterGroupsInput(
            providers: providers.map { provider in
                CCHProviderGroupPresentationInput(
                    providerId: provider.id,
                    groupTag: provider.groupTag,
                    overrideNames: providerGroupAssignmentOverrides[provider.id]
                )
            }
        )
        if let cached = providerFilterGroupsCache, cached.input == input {
            return cached.groups
        }

        let groups = CCHProviderGroupsBuilder.filterGroups(input)
        providerFilterGroupsCache = (input, groups)
        return groups
    }

    private func mergedAssignableProviderGroups(_ officialGroups: [CCHProviderGroup]) -> [CCHProviderGroup] {
        let input = CCHAssignableProviderGroupsInput(
            officialGroups: officialGroups,
            providerGroupTags: providers.map(\.groupTag)
        )
        if let cached = assignableProviderGroupsCache, cached.input == input {
            return cached.groups
        }

        let groups = CCHProviderGroupsBuilder.assignableGroups(input)
        assignableProviderGroupsCache = (input, groups)
        return groups
    }

    private func providerGroupTag(from groups: Set<String>) -> String? {
        let values = groups
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isDefaultProviderGroup($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return values.isEmpty ? nil : values.joined(separator: ",")
    }

    private func storedGroupNames(for provider: CCHProvider) -> Set<String> {
        CCHProviderGroupPresentationBuilder.storedGroupNames(from: provider.groupTag)
    }

    private func reconcileProviderGroupAssignmentOverrides() {
        var nextOverrides = providerGroupAssignmentOverrides
        for provider in providers where nextOverrides[provider.id] == storedGroupNames(for: provider) {
            nextOverrides[provider.id] = nil
        }
        let providerIds = Set(providers.map(\.id))
        nextOverrides = nextOverrides.filter { providerIds.contains($0.key) }
        if providerGroupAssignmentOverrides != nextOverrides {
            providerGroupAssignmentOverrides = nextOverrides
        }
    }

    private func rebuildProviderFilterSnapshot(
        groups: [String]? = nil,
        sortMode: CCHProviderSortMode = .preserveCurrentOrder
    ) {
        let resolvedGroups = groups ?? computedProviderGroups()
        let groupFiltered: [CCHProvider]
        if selectedProviderGroups.isEmpty {
            groupFiltered = providers
        } else {
            groupFiltered = providers.filter { provider in
                displayGroupTitles(for: provider).contains { selectedProviderGroups.contains($0) }
            }
        }

        let orderedGroupProviders = providerSortState.order(groupFiltered, mode: sortMode) { provider in
            CCHProviderSortDescriptor(
                id: provider.id,
                isEnabled: provider.isEnabled,
                hasMiniProbe: providerMiniProbeSelectedProviderIds.contains(provider.id),
                isPinned: pinnedProviderIds.contains(provider.id)
            )
        }
        let filtered = CCHProviderNameSearch.filter(
            orderedGroupProviders,
            query: providerSearchText,
            name: \.name
        )
        var enabledCount = 0
        var unhealthyCount = 0
        for provider in filtered {
            if provider.isEnabled {
                enabledCount += 1
            }
            if CCHProviderStatsBuilder.isUnhealthy(provider) {
                unhealthyCount += 1
            }
        }
        let next = CCHProviderFilterSnapshot(
            groups: resolvedGroups,
            providers: filtered,
            groupProviderCount: groupFiltered.count,
            enabledCount: enabledCount,
            unhealthyCount: unhealthyCount
        )
        if providerFilterSnapshot != next {
            providerFilterSnapshot = next
        }
    }

    private func rebuildLeaderboardSummary() {
        let next = CCHLeaderboardSummaryBuilder.makeSummary(from: leaderboard)
        if leaderboardSummary != next {
            leaderboardSummary = next
        }
    }

    private func rebuildMenuBarRunningLogs() {
        cachedMenuBarRunningLogs = CCHMenuBarRunningLogBuilder.runningLogs(from: recentLogs)
        if !cachedMenuBarRunningLogs.isEmpty {
            lastStatusBarRunningSeenAt = Date()
        }
    }

    private func updateStatusBarSnapshot() {
        let next = CCHStatusBarSnapshotBuilder.makeSnapshot(
            CCHStatusBarSnapshotInput(
                showsDetails: showStatusBarDetails,
                reducedMotion: statusBarReducedMotion,
                idlePrimary: menuBarText,
                idleDetail: menuBarIdleDetail,
                idleCacheState: statusBarCacheState,
                recentLogs: recentLogs,
                runningLogs: cachedMenuBarRunningLogs,
                cacheStatusByLogId: cacheStatusByLogId,
                cacheAlertLogIds: Set([menuBarCacheAlertLogId, simulatedCacheAlertLogId].compactMap { $0 }),
                generatedAt: Date()
            )
        )

        if statusBarSnapshot != next {
            statusBarSnapshot = next
        }
    }

    private func mergeRecentLogHistory(_ values: [CCHLogEntry]) {
        recentLogHistory = CCHCacheStatusMapBuilder.mergeHistory(
            incomingLogs: values,
            history: recentLogHistory,
            limit: CCHRetentionLimits.recentLogHistory
        )
    }

    private func announceLatestCacheAlert(logId: Int?) {
        guard let logId else { return }
        guard logId != lastAnnouncedCacheAlertLogId else { return }
        lastAnnouncedCacheAlertLogId = logId
        menuBarCacheAlertLogId = logId
        cacheAlertDismissTask?.cancel()
        cacheAlertDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            if self.menuBarCacheAlertLogId == logId {
                self.menuBarCacheAlertLogId = nil
                self.updateStatusBarSnapshot()
            }
        }
    }

    func startUpdateCheckTimer() {
        updateCheckTimer?.cancel()
        guard checkForUpdatesEnabled else {
            updateCheckTimer = nil
            return
        }
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

    static func loadProviderMiniProbeHistories() -> [Int: [CCHProviderMiniProbeSample]] {
        guard
            let data = UserDefaults.standard.data(forKey: CCHProviderMiniProbeStorage.historiesKey),
            let decoded = try? JSONDecoder().decode([String: [CCHProviderMiniProbeSample]].self, from: data)
        else { return [:] }

        var result: [Int: [CCHProviderMiniProbeSample]] = [:]
        for (key, samples) in decoded {
            guard let providerId = Int(key) else { continue }
            let normalized = samples
                .sorted { $0.createdAt < $1.createdAt }
                .suffix(CCHProviderMiniProbeLimits.maxSamples)
            if !normalized.isEmpty {
                result[providerId] = Array(normalized)
            }
        }
        return result
    }

    func saveProviderMiniProbeSelectedProviderIds() {
        UserDefaults.standard.set(
            providerMiniProbeSelectedProviderIds.sorted(),
            forKey: CCHProviderMiniProbeStorage.selectedProviderIdsKey
        )
    }

    private func savePinnedProviderIds() {
        UserDefaults.standard.set(
            pinnedProviderIds.sorted(),
            forKey: CCHProviderPinningStorage.pinnedProviderIdsKey
        )
    }

    static func loadProviderMiniProbeModelOverrides() -> [Int: String] {
        guard
            let data = UserDefaults.standard.data(forKey: CCHProviderMiniProbeStorage.modelOverridesKey),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }

        var result: [Int: String] = [:]
        for (key, model) in decoded {
            guard let providerId = Int(key) else { continue }
            let normalized = normalizedProviderTestModel(model)
            if !normalized.isEmpty {
                result[providerId] = normalized
            }
        }
        return result
    }

    func saveProviderMiniProbeModelOverrides() {
        let encodable = providerMiniProbeModelOverrides.reduce(into: [String: String]()) { result, entry in
            let normalized = normalizedProviderTestModel(entry.value)
            if !normalized.isEmpty {
                result[String(entry.key)] = normalized
            }
        }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: CCHProviderMiniProbeStorage.modelOverridesKey)
        }
    }

    func saveProviderMiniProbeHistories() {
        saveProviderMiniProbeHistoriesDebounced()
    }

    func saveProviderMiniProbeHistoriesDebounced() {
        providerMiniProbeHistoriesSaveTask?.cancel()
        let histories = providerMiniProbeHistories
        providerMiniProbeHistoriesSaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            Self.persistProviderMiniProbeHistories(histories)
        }
    }

    func saveProviderMiniProbeHistoriesNow() {
        Self.persistProviderMiniProbeHistories(providerMiniProbeHistories)
    }

    nonisolated static func persistProviderMiniProbeHistories(_ histories: [Int: [CCHProviderMiniProbeSample]]) {
        var encodable: [String: [CCHProviderMiniProbeSample]] = [:]
        for (providerId, samples) in histories {
            let normalized = samples
                .sorted { $0.createdAt < $1.createdAt }
                .suffix(CCHProviderMiniProbeLimits.maxSamples)
            if !normalized.isEmpty {
                encodable[String(providerId)] = Array(normalized)
            }
        }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: CCHProviderMiniProbeStorage.historiesKey)
        }
    }

    static func latestProviderMiniProbeRunDates(from histories: [Int: [CCHProviderMiniProbeSample]]) -> [Int: Date] {
        histories.reduce(into: [Int: Date]()) { result, entry in
            let countedSamples = entry.value.filter { $0.status == .success || $0.status == .warning }
            if let latest = countedSamples.map(\.createdAt).max() {
                result[entry.key] = latest
            }
        }
    }

    func pruneProviderMiniProbeData() {
        let providerIds = Set(providers.map(\.id))
        let nextPinned = pinnedProviderIds.intersection(providerIds)
        if nextPinned != pinnedProviderIds {
            pinnedProviderIds = nextPinned
            savePinnedProviderIds()
        }

        let nextSelected = providerMiniProbeSelectedProviderIds.intersection(providerIds)
        if nextSelected != providerMiniProbeSelectedProviderIds {
            providerMiniProbeSelectedProviderIds = nextSelected
            saveProviderMiniProbeSelectedProviderIds()
        }

        let nextHistories = providerMiniProbeHistories.filter { providerIds.contains($0.key) }
        if nextHistories != providerMiniProbeHistories {
            providerMiniProbeHistories = nextHistories
            saveProviderMiniProbeHistories()
        }
        let nextLastRunDates = providerMiniProbeLastRunAtByProviderId.filter { providerIds.contains($0.key) }
        if nextLastRunDates != providerMiniProbeLastRunAtByProviderId {
            providerMiniProbeLastRunAtByProviderId = nextLastRunDates
        }
        providerMiniProbeFailureBackoffUntilByProviderId = providerMiniProbeFailureBackoffUntilByProviderId.filter { providerIds.contains($0.key) }
        providerMiniProbeFailureCountByProviderId = providerMiniProbeFailureCountByProviderId.filter { providerIds.contains($0.key) }
        providerMiniProbeRunTokens = providerMiniProbeRunTokens.filter { providerIds.contains($0.key) }
        let staleTaskIds = providerMiniProbeTasks.keys.filter { !providerIds.contains($0) }
        for providerId in staleTaskIds {
            providerMiniProbeTasks[providerId]?.cancel()
            providerMiniProbeTasks[providerId] = nil
        }

        let nextModelOverrides = providerMiniProbeModelOverrides.filter { providerIds.contains($0.key) }
        if nextModelOverrides != providerMiniProbeModelOverrides {
            providerMiniProbeModelOverrides = nextModelOverrides
            saveProviderMiniProbeModelOverrides()
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
        let sortedNext = next.sorted { $0.host < $1.host }
        if sortedNext != upstreamRateCredentials {
            upstreamRateCredentials = sortedNext
            if persist {
                do {
                    try upstreamCredentialStore.save(upstreamRateCredentials)
                } catch {
                    flashActionMessage(error.localizedDescription, duration: 5, isWarning: true)
                    return false
                }
            }
        }
        return true
    }

    private func mergedUpstreamCredential(_ credential: UpstreamRateCredential) -> UpstreamRateCredential {
        guard let existing = upstreamRateCredentials.first(where: { $0.host == credential.host }) else {
            return credential
        }
        var next = credential
        if next.userAgent.isEmpty {
            next.userAgent = existing.userAgent
        }
        if next.sub2AuthToken.isEmpty {
            next.sub2AuthToken = existing.sub2AuthToken
        }
        if next.sub2RefreshToken.isEmpty {
            next.sub2RefreshToken = existing.sub2RefreshToken
        }
        if next.sub2TokenExpiresAt == nil {
            next.sub2TokenExpiresAt = existing.sub2TokenExpiresAt
        }
        if next.sub2CookieHeader.isEmpty {
            next.sub2CookieHeader = existing.sub2CookieHeader
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
        let snapshot = UpstreamRateSnapshot(host: normalizedHost, sourceType: sourceType, status: status)
        var next = upstreamRateSnapshots.filter { $0.host != normalizedHost }
        next.append(snapshot)
        next.sort { $0.host.localizedCaseInsensitiveCompare($1.host) == .orderedAscending }
        if upstreamRateSnapshots != next {
            upstreamRateSnapshots = next
        }
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
        let inputs = upstreamProviderInputs
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

private func isNewerLog(_ lhs: CCHLogEntry, _ rhs: CCHLogEntry) -> Bool {
    guard
        let lhsDate = parsedCCHDate(lhs.createdAt),
        let rhsDate = parsedCCHDate(rhs.createdAt)
    else { return lhs.id > rhs.id }
    return lhsDate > rhsDate
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

func formatProviderModelTestTiming(_ result: CCHProviderModelTestResult) -> String {
    var parts: [String] = []
    if let ttfbMs = result.ttfbMs {
        parts.append("首字节 \(formatProbeLatency(ttfbMs))")
    }
    if let latencyMs = result.latencyMs {
        parts.append("总延迟 \(formatProbeLatency(latencyMs))")
    }
    return parts.isEmpty ? "-" : parts.joined(separator: " · ")
}

func formatProviderMiniProbeHour(_ value: Double) -> String {
    let clamped = min(max(value, 0), 24)
    if clamped >= 24 {
        return "24:00"
    }
    let totalMinutes = Int((clamped * 60).rounded())
    let hour = totalMinutes / 60
    let minute = totalMinutes % 60
    return String(format: "%02d:%02d", hour, minute)
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
    static let cacheLock = NSLock()

    static func cachedDate(for key: String) -> Date? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[key]
    }

    static func remember(_ date: Date, for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
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
    if let cached = CCHDateParser.cachedDate(for: trimmed) {
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
