import Foundation
import Network

struct CCHConfig {
    var baseURL: String
    var token: String
    var envPath: String
}

struct CCHOverview {
    var concurrentSessions: Int = 0
    var todayRequests: Int = 0
    var todayCost: Double = 0
    var avgResponseTime: Int = 0
    var todayErrorRate: Double = 0
    var recentMinuteRequests: Int = 0
    var yesterdaySamePeriodRequests: Int = 0
    var yesterdaySamePeriodCost: Double = 0
}

struct CCHActiveSession: Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let providerId: Int
    let userName: String
    let keyName: String
    let providerName: String
    let model: String
    let apiType: String
    let startTime: Int
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let costUsd: Double
    let durationMs: Int
    let requestCount: Int
    let concurrentCount: Int
    let status: String
}

struct CCHStatusRunningItem: Identifiable, Equatable {
    let id: String
    let logId: Int?
    let providerName: String
    let model: String
    let multiplier: Double
    let isFastTier: Bool
    let isRetrying: Bool
    let startedAt: Date?
    let cacheState: CCHCacheVisibilityState
}

struct CCHStatusBarSnapshot: Equatable {
    let showsDetails: Bool
    let reducedMotion: Bool
    let idlePrimary: String
    let idleDetail: String
    let idleCacheState: CCHCacheVisibilityState
    let runningItems: [CCHStatusRunningItem]
    let hasRecentLogs: Bool
    let generatedAt: Date

    static func == (lhs: CCHStatusBarSnapshot, rhs: CCHStatusBarSnapshot) -> Bool {
        lhs.showsDetails == rhs.showsDetails
            && lhs.reducedMotion == rhs.reducedMotion
            && lhs.idlePrimary == rhs.idlePrimary
            && lhs.idleDetail == rhs.idleDetail
            && lhs.idleCacheState == rhs.idleCacheState
            && lhs.runningItems == rhs.runningItems
            && lhs.hasRecentLogs == rhs.hasRecentLogs
    }
}

struct CCHLeaderboardModelStat: Identifiable {
    let id: String
    let model: String
    let requests: Int
    let cost: Double
    let tokens: Int
    let inputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cacheHitRateOverride: Double?

    var cacheHitRate: Double? {
        cacheHitRateOverride
    }
}

struct CCHLeaderboardEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let requests: Int
    let cost: Double
    let tokens: Int
    let inputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let cacheHitRateOverride: Double?
    let successRate: Double?
    let modelStats: [CCHLeaderboardModelStat]

    var cacheHitRate: Double? {
        cacheHitRateOverride
    }

    func mergingCacheData(from cache: CCHLeaderboardEntry) -> CCHLeaderboardEntry {
        CCHLeaderboardEntry(
            id: id,
            title: title,
            subtitle: subtitle,
            requests: requests,
            cost: cost,
            tokens: tokens,
            inputTokens: cache.inputTokens > 0 ? cache.inputTokens : inputTokens,
            cacheCreationTokens: cache.inputTokens > 0 || cache.cacheHitRateOverride != nil ? cache.cacheCreationTokens : cacheCreationTokens,
            cacheReadTokens: cache.inputTokens > 0 || cache.cacheHitRateOverride != nil ? cache.cacheReadTokens : cacheReadTokens,
            cacheHitRateOverride: cache.cacheHitRateOverride ?? cacheHitRateOverride,
            successRate: successRate,
            modelStats: mergeLeaderboardModelStats(primary: modelStats, cache: cache.modelStats)
        )
    }
}

struct CCHLogSummary {
    var totalRequests: Int = 0
    var totalCost: Double = 0
    var totalTokens: Int = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
}

struct CCHProviderChainItem: Identifiable {
    let id = UUID()
    let name: String
    let providerType: String
    let reason: String
    let circuitState: String
    let priority: Int
    let weight: Int
    let groupTag: String
    let costMultiplier: Double
    let statusCode: Int?
    let attemptNumber: Int?
    let errorMessage: String
}

struct CCHLogEntry: Identifiable {
    let id: Int
    let createdAt: String
    let sessionId: String
    let requestSequence: Int
    let userName: String
    let keyName: String
    let providerName: String
    let model: String
    let originalModel: String
    let endpoint: String
    let statusCode: Int?
    let messagesCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let costUsd: Double
    let durationMs: Int?
    let ttfbMs: Int?
    let tokensPerSecond: Double?
    let costMultiplier: Double
    let isFastTier: Bool
    let errorMessage: String
    let providerChain: [CCHProviderChainItem]
}

enum CCHCacheVisibilityState: Equatable {
    case normal
    case rebuilding
}

struct CCHCacheStatusContext: Equatable {
    let state: CCHCacheVisibilityState
    let createdTokens: Int
    let readTokens: Int
}

struct CCHProviderHealth {
    var circuitState: String = "closed"
    var failureCount: Int = 0
    var lastFailureTime: Int?
    var circuitOpenUntil: Int?
    var recoveryMinutes: Int?
}

struct CCHProvider: Identifiable {
    let id: Int
    let name: String
    let providerType: String
    let vendorId: Int?
    let apiURL: String
    let websiteURL: String
    let isEnabled: Bool
    let priority: Int
    let weight: Int
    let groupTag: String
    let costMultiplier: Double
    let todayCalls: Int
    let todayCost: Double
    let lastCallTime: String
    let lastCallModel: String
    let allowedModels: String
    let allowedClients: String
    let modelRedirects: String
    let testModel: String
    let testModelOptions: [String]
    let proxyURL: String
    let proxyFallbackToDirect: Bool
    let customHeaders: [String: String]?
    let limitText: String
    let health: CCHProviderHealth
}

struct CCHProviderGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let providerCount: Int?
    let costMultiplier: Double?
}

struct CCHProviderEndpoint: Identifiable {
    let id: Int
    let label: String
    let isEnabled: Bool
}

struct CCHLogsPage {
    let logs: [CCHLogEntry]
    let total: Int
    let summary: CCHLogSummary
}

struct CCHProbeResult {
    let ok: Bool
    let method: String
    let statusCode: Int?
    let latencyMs: Double?
    let errorMessage: String
}

struct CCHProviderModelTestProgress {
    let completed: Int
    let total: Int
    let currentModel: String
}

struct CCHGitHubRelease {
    let tag: String
    let name: String
    let body: String
    let htmlURL: URL
    let publishedAt: Date?
}

struct CCHLeaderboardSummary: Equatable {
    var requests = 0
    var cost: Double = 0
    var tokens = 0
    var cacheHitRate: Double?
}

struct CCHProviderFilterSnapshot {
    var groups: [String] = ["全部"]
    var providers: [CCHProvider] = []
    var enabledCount = 0
    var unhealthyCount = 0
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingToken
    case httpError(Int)
    case parseError
    case actionError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 CCH 地址"
        case .invalidResponse: return "CCH 响应无效"
        case .missingToken: return "缺少 CCH API Key"
        case .httpError(let code): return "HTTP 错误 \(code)"
        case .parseError: return "数据解析失败"
        case .actionError(let message): return CCHDisplaySanitizer.backendError(message)
        }
    }
}

actor APIService {
    private let session: URLSession
    private let directSession: URLSession
    private var cachedToken: (path: String, modifiedAt: Date?, token: String)?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        let directConfig = URLSessionConfiguration.default
        directConfig.timeoutIntervalForRequest = 15
        directConfig.timeoutIntervalForResource = 30
        directConfig.connectionProxyDictionary = [:]
        self.directSession = URLSession(configuration: directConfig)
    }

    func fetchOverview(config: CCHConfig) async throws -> CCHOverview {
        let data: Any
        do {
            data = try await getV1(config: config, path: "/api/v1/dashboard/overview")
        } catch where shouldFallbackToActions(error) {
            data = try await postAction(config: config, module: "overview", action: "getOverviewData")
        }
        guard let dict = data as? [String: Any] else { throw APIError.parseError }
        return CCHOverview(
            concurrentSessions: intValue(dict["concurrentSessions"]),
            todayRequests: intValue(dict["todayRequests"]),
            todayCost: doubleValue(dict["todayCost"]),
            avgResponseTime: intValue(dict["avgResponseTime"]),
            todayErrorRate: doubleValue(dict["todayErrorRate"]),
            recentMinuteRequests: intValue(dict["recentMinuteRequests"]),
            yesterdaySamePeriodRequests: intValue(dict["yesterdaySamePeriodRequests"]),
            yesterdaySamePeriodCost: doubleValue(dict["yesterdaySamePeriodCost"])
        )
    }

    func fetchActiveSessions(config: CCHConfig) async throws -> [CCHActiveSession] {
        let data: Any
        do {
            data = try await getV1(
                config: config,
                path: "/api/v1/sessions",
                queryItems: [
                    URLQueryItem(name: "state", value: "active"),
                    URLQueryItem(name: "pageSize", value: "100")
                ]
            )
        } catch where shouldFallbackToActions(error) {
            data = try await postAction(config: config, module: "active-sessions", action: "getActiveSessions")
        }
        return itemRows(from: data).map(parseActiveSession)
    }

    func fetchLeaderboard(
        config: CCHConfig,
        period: String,
        scope: String,
        cacheHitMode: Bool = false
    ) async throws -> [CCHLeaderboardEntry] {
        _ = cacheHitMode
        do {
            return try await fetchOfficialLeaderboard(config: config, period: period, scope: scope)
        } catch where shouldFallbackToActions(error) {
            let rows = try await fetchUsageLogRowsForLeaderboard(config: config, period: period)
            return aggregateLeaderboard(rows: rows, scope: scope)
        }
    }

    private func fetchUsageLogRowsForLeaderboard(config: CCHConfig, period: String) async throws -> [[String: Any]] {
        let pageSize = 100
        let startDate = leaderboardStartDate(period)
        let firstQueryItems = usageLogQueryItems(
            page: 1,
            pageSize: pageSize,
            startDate: startDate,
            model: "",
            statusCode: "",
            sessionId: ""
        )
        let firstPage = try await getV1(config: config, path: "/api/v1/usage-logs", queryItems: firstQueryItems)
        var rows = itemRows(from: firstPage)
        let totalPages = usageLogTotalPages(from: firstPage)
        guard totalPages > 1 else { return rows }

        for page in 2...totalPages {
            let queryItems = usageLogQueryItems(
                page: page,
                pageSize: pageSize,
                startDate: startDate,
                model: "",
                statusCode: "",
                sessionId: ""
            )
            let data = try await getV1(config: config, path: "/api/v1/usage-logs", queryItems: queryItems)
            rows.append(contentsOf: itemRows(from: data))
        }
        return rows
    }

    private func fetchUsageLogPage(
        config: CCHConfig,
        page: Int,
        pageSize: Int,
        startDate: Date?
    ) async throws -> Any {
        let queryItems = usageLogQueryItems(
            page: page,
            pageSize: pageSize,
            startDate: startDate,
            model: "",
            statusCode: "",
            sessionId: ""
        )
        return try await getV1(config: config, path: "/api/v1/usage-logs", queryItems: queryItems)
    }

    func fetchLogs(
        config: CCHConfig,
        page: Int,
        pageSize: Int,
        startDate: Date?,
        model: String,
        statusCode: String,
        sessionId: String,
        includeStats: Bool = true
    ) async throws -> CCHLogsPage {
        let queryItems = usageLogQueryItems(
            page: page,
            pageSize: pageSize,
            startDate: startDate,
            model: model,
            statusCode: statusCode,
            sessionId: sessionId
        )
        let data: Any
        do {
            data = try await getV1(config: config, path: "/api/v1/usage-logs", queryItems: queryItems)
        } catch where shouldFallbackToActions(error) {
            return try await fetchLegacyLogs(
                config: config,
                page: page,
                pageSize: pageSize,
                startDate: startDate,
                model: model,
                statusCode: statusCode,
                sessionId: sessionId
            )
        }
        guard let dict = data as? [String: Any] else { throw APIError.parseError }
        let rows = itemRows(from: dict)
        let stats: [String: Any]
        if includeStats {
            stats = (try? await getV1(config: config, path: "/api/v1/usage-logs/stats", queryItems: queryItems)) as? [String: Any] ?? [:]
        } else {
            stats = [:]
        }
        let pageInfo = dict["pageInfo"] as? [String: Any] ?? [:]
        return CCHLogsPage(
            logs: rows.map(parseLog),
            total: intValue(pageInfo["total"], fallback: intValue(dict["total"], fallback: rows.count)),
            summary: CCHLogSummary(
                totalRequests: intValue(stats["totalRequests"]),
                totalCost: doubleValue(stats["totalCost"]),
                totalTokens: intValue(stats["totalTokens"]),
                inputTokens: intValue(stats["totalInputTokens"]),
                outputTokens: intValue(stats["totalOutputTokens"]),
                cacheCreationTokens: cacheCreationTokens(from: stats, prefix: "total"),
                cacheReadTokens: intValue(stats["totalCacheReadTokens"])
            )
        )
    }

    func fetchProviders(config: CCHConfig, includeUsage: Bool = true) async throws -> [CCHProvider] {
        let providersData: Any
        let healthData: Any?
        let usageRows: [CCHLeaderboardEntry]
        do {
            providersData = try await getV1(config: config, path: "/api/v1/providers")
            healthData = try? await getV1(config: config, path: "/api/v1/providers/health")
            usageRows = includeUsage
                ? ((try? await fetchOfficialLeaderboardRows(config: config, period: "daily", scope: "provider", cacheHitMode: false)) ?? [])
                : []
        } catch where shouldFallbackToActions(error) {
            providersData = try await postAction(config: config, module: "providers", action: "getProviders")
            healthData = try? await postAction(config: config, module: "providers", action: "getProvidersHealthStatus")
            if includeUsage {
                let usageLogRows = (try? await fetchUsageLogRowsForLeaderboard(config: config, period: "daily")) ?? []
                usageRows = aggregateLeaderboard(rows: usageLogRows, scope: "provider")
            } else {
                usageRows = []
            }
        }
        let rows = itemRows(from: providersData)
        let healthMap = healthData as? [String: Any] ?? [:]
        let usageById = Dictionary(uniqueKeysWithValues: usageRows.map { ($0.id, $0) })
        let usageByName = Dictionary(usageRows.map { ($0.title.lowercased(), $0) }, uniquingKeysWith: mergeLeaderboardEntries)

        return rows.map { row in
            let id = intValue(row["id"])
            let name = stringValue(row["name"], fallback: "Provider")
            let providerType = stringValue(row["providerType"])
            let usage = usageById["provider-\(id)"] ?? usageByName[name.lowercased()]
            let healthDict = healthMap[String(id)] as? [String: Any] ?? [:]
            let health = CCHProviderHealth(
                circuitState: stringValue(healthDict["circuitState"], fallback: "closed"),
                failureCount: intValue(healthDict["failureCount"]),
                lastFailureTime: optionalInt(healthDict["lastFailureTime"]),
                circuitOpenUntil: optionalInt(healthDict["circuitOpenUntil"]),
                recoveryMinutes: optionalInt(healthDict["recoveryMinutes"])
            )

            return CCHProvider(
                id: id,
                name: name,
                providerType: providerType,
                vendorId: firstOptionalInt(row, keys: ["providerVendorId", "vendorId"]),
                apiURL: firstStringValue(row, keys: ["url", "endpointUrl", "apiUrl", "apiURL"]),
                websiteURL: firstStringValue(row, keys: ["websiteUrl", "websiteURL", "homepageUrl", "homepageURL"]),
                isEnabled: boolValue(row["isEnabled"]),
                priority: intValue(row["priority"]),
                weight: intValue(row["weight"]),
                groupTag: firstStringValue(row, keys: ["groupTag", "group_tag", "providerGroup"], fallback: "default"),
                costMultiplier: doubleValue(row["costMultiplier"], fallback: 1),
                todayCalls: usage?.requests ?? intValue(row["todayCallCount"]),
                todayCost: usage?.cost ?? doubleValue(row["todayTotalCostUsd"]),
                lastCallTime: stringValue(row["lastCallTime"]),
                lastCallModel: stringValue(row["lastCallModel"]),
                allowedModels: compactArrayDescription(row["allowedModels"]),
                allowedClients: compactArrayDescription(row["allowedClients"]),
                modelRedirects: compactArrayDescription(row["modelRedirects"]),
                testModel: preferredProviderTestModel(row, providerType: providerType),
                testModelOptions: providerTestModelOptions(row, providerType: providerType),
                proxyURL: firstStringValue(row, keys: ["proxyUrl", "proxy_url"]),
                proxyFallbackToDirect: boolValue(row["proxyFallbackToDirect"] ?? row["proxy_fallback_to_direct"]),
                customHeaders: providerCustomHeaders(row),
                limitText: buildLimitText(row),
                health: health
            )
        }
    }

    func fetchProviderGroups(config: CCHConfig) async throws -> [CCHProviderGroup] {
        let data = try await getV1(config: config, path: "/api/v1/provider-groups")
        if let values = providerGroupStringRows(from: data) {
            return values.compactMap(parseProviderGroup)
        }
        return itemRows(from: data).compactMap(parseProviderGroup)
    }

    func setProviderGroups(config: CCHConfig, providerId: Int, groupTag: String?) async throws {
        let bodyValue: Any = groupTag ?? NSNull()
        _ = try await patchV1(
            config: config,
            path: "/api/v1/providers/\(providerId)",
            body: ["group_tag": bodyValue]
        )
    }

    func setProviderEnabled(config: CCHConfig, providerId: Int, enabled: Bool) async throws {
        do {
            _ = try await patchV1(config: config, path: "/api/v1/providers/\(providerId)", body: ["is_enabled": enabled])
        } catch where shouldFallbackToActions(error) {
            _ = try await postAction(
                config: config,
                module: "providers",
                action: "editProvider",
                body: ["providerId": providerId, "is_enabled": enabled]
            )
        }
    }

    func setProviderMultiplier(config: CCHConfig, providerId: Int, multiplier: Double) async throws {
        do {
            _ = try await patchV1(
                config: config,
                path: "/api/v1/providers/\(providerId)",
                body: ["cost_multiplier": multiplier]
            )
        } catch APIError.httpError(let code) where code == 400 || code == 422 {
            _ = try await patchV1(
                config: config,
                path: "/api/v1/providers/\(providerId)",
                body: ["costMultiplier": multiplier]
            )
        } catch where shouldFallbackToActions(error) {
            _ = try await postAction(
                config: config,
                module: "providers",
                action: "editProvider",
                body: ["providerId": providerId, "costMultiplier": multiplier]
            )
        }
    }

    func resetProviderCircuit(config: CCHConfig, providerId: Int) async throws {
        do {
            _ = try await postV1(config: config, path: "/api/v1/providers/\(providerId)/circuit:reset", body: [:])
        } catch where shouldFallbackToActions(error) {
            _ = try await postAction(
                config: config,
                module: "providers",
                action: "resetProviderCircuit",
                body: ["providerId": providerId]
            )
        }
    }

    func testProviderModel(config: CCHConfig, provider: CCHProvider, model: String? = nil) async throws -> CCHProviderModelTestResult {
        guard let providerURL = normalizedProviderTestURL(provider.apiURL) else {
            throw APIError.actionError("渠道地址无效，无法进行模型测试")
        }

        let apiKey = try await revealProviderKey(config: config, providerId: provider.id)
        let providerType = normalizedProviderType(provider.providerType)
        let isGemini = providerType == "gemini" || providerType == "gemini-cli"
        let testModel = normalizedTestModel(model) ?? provider.testModel

        var body: [String: Any] = [
            "providerUrl": providerURL,
            "apiKey": apiKey,
            "model": testModel,
            "timeoutMs": providerModelTestTimeoutMs(providerType)
        ]

        let proxyURL = provider.proxyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !proxyURL.isEmpty {
            body["proxyUrl"] = proxyURL
            body["proxyFallbackToDirect"] = provider.proxyFallbackToDirect
        }

        let path: String
        if isGemini {
            path = "/api/v1/providers/test:gemini"
        } else {
            path = "/api/v1/providers/test:unified"
            body["providerType"] = providerType
            if let customHeaders = provider.customHeaders, !customHeaders.isEmpty {
                body["customHeaders"] = customHeaders
            }
        }

        let data = try await postV1(config: config, path: path, body: body)
        return parseProviderModelTestResult(data)
    }

    func revealProviderKey(config: CCHConfig, providerId: Int) async throws -> String {
        let data = try await getV1(config: config, path: "/api/v1/providers/\(providerId)/key:reveal")
        guard let dict = data as? [String: Any] else { throw APIError.parseError }
        let key = stringValue(dict["key"]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw APIError.actionError("渠道 API Key 为空") }
        return key
    }

    func probeFirstEndpoint(config: CCHConfig, provider: CCHProvider) async throws -> CCHProbeResult {
        if let result = await probeConfiguredProviderURL(provider) {
            return result
        }

        if let vendorId = provider.vendorId {
            let endpointsData: Any
            do {
                endpointsData = try await getV1(
                    config: config,
                    path: "/api/v1/provider-vendors/\(vendorId)/endpoints",
                    queryItems: [
                        URLQueryItem(name: "providerType", value: provider.providerType),
                        URLQueryItem(name: "dashboard", value: "true")
                    ]
                )
            } catch where shouldFallbackToActions(error) {
                endpointsData = try await postAction(
                    config: config,
                    module: "providers",
                    action: "getProviderEndpoints",
                    body: ["vendorId": vendorId, "providerType": provider.providerType]
                )
            }
            let rows = itemRows(from: endpointsData)
            if let endpoint = rows.first(where: isEndpointEnabled) ?? rows.first,
               let endpointId = firstOptionalInt(endpoint, keys: ["id", "endpointId", "providerEndpointId"]) {
                return try await probeProviderEndpoint(config: config, endpointId: endpointId)
            }
        }

        throw APIError.actionError("没有可测速的端点")
    }

    private func probeProviderEndpoint(config: CCHConfig, endpointId: Int) async throws -> CCHProbeResult {
        let data: Any
        do {
            data = try await postV1(
                config: config,
                path: "/api/v1/provider-endpoints/\(endpointId):probe",
                body: ["timeoutMs": 12000]
            )
        } catch where shouldFallbackToActions(error) {
            data = try await postAction(
                config: config,
                module: "providers",
                action: "probeProviderEndpoint",
                body: ["endpointId": endpointId, "timeoutMs": 12000]
            )
        }
        guard let dict = data as? [String: Any] else { throw APIError.parseError }
        let result = dict["result"] as? [String: Any] ?? dict

        return CCHProbeResult(
            ok: boolValue(result["ok"]),
            method: stringValue(result["method"]),
            statusCode: optionalInt(result["statusCode"]),
            latencyMs: firstOptionalDouble(result, keys: ["latencyMs", "durationMs", "duration"]),
            errorMessage: stringValue(result["errorMessage"])
        )
    }

    private func probeConfiguredProviderURL(_ provider: CCHProvider) async -> CCHProbeResult? {
        let rawURL = provider.apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawURL.isEmpty else { return nil }
        let normalizedURL = rawURL.hasPrefix("http://") || rawURL.hasPrefix("https://")
            ? rawURL
            : "https://\(rawURL)"
        guard let url = URL(string: normalizedURL) else {
            return CCHProbeResult(
                ok: false,
                method: "URL",
                statusCode: nil,
                latencyMs: nil,
                errorMessage: "端点地址无效"
            )
        }

        if let tcpLatencyMs = try? await probeTCPConnection(url) {
            let isSuspiciousLocalProxy = isLikelyLocalProxyLatency(tcpLatencyMs)
            if !isSuspiciousLocalProxy || url.scheme?.lowercased() != "https" {
                return CCHProbeResult(
                    ok: true,
                    method: "TCP",
                    statusCode: nil,
                    latencyMs: tcpLatencyMs,
                    errorMessage: ""
                )
            }

            if let tlsLatencyMs = try? await probeTLSConnection(url) {
                let shouldEstimateRTT = tlsLatencyMs >= 80 && tlsLatencyMs >= tcpLatencyMs * 6
                return CCHProbeResult(
                    ok: true,
                    method: shouldEstimateRTT ? "链路估算" : "TLS",
                    statusCode: nil,
                    latencyMs: shouldEstimateRTT ? max(tcpLatencyMs, tlsLatencyMs / 2) : tlsLatencyMs,
                    errorMessage: ""
                )
            }
        }

        let start = Date()
        do {
            let response = try await probeURL(url, method: "HEAD")
            let latencyMs = max(Date().timeIntervalSince(start) * 1000, 0.1)
            let statusCode = response.statusCode
            if (200...499).contains(statusCode) {
                return CCHProbeResult(
                    ok: true,
                    method: "HEAD",
                    statusCode: statusCode,
                    latencyMs: latencyMs,
                    errorMessage: ""
                )
            }
            return CCHProbeResult(
                ok: false,
                method: "HEAD",
                statusCode: statusCode,
                latencyMs: latencyMs,
                errorMessage: "端点返回 HTTP \(statusCode)"
            )
        } catch {
            let getStart = Date()
            do {
                let response = try await probeURL(url, method: "GET")
                let latencyMs = max(Date().timeIntervalSince(getStart) * 1000, 0.1)
                let statusCode = response.statusCode
                return CCHProbeResult(
                    ok: (200...499).contains(statusCode),
                    method: "GET",
                    statusCode: statusCode,
                    latencyMs: latencyMs,
                    errorMessage: (200...499).contains(statusCode) ? "" : "端点返回 HTTP \(statusCode)"
                )
            } catch {
                return CCHProbeResult(
                    ok: false,
                    method: "GET",
                    statusCode: nil,
                    latencyMs: nil,
                    errorMessage: "测速失败: \(error.localizedDescription)"
                )
            }
        }
    }

    private func probeTCPConnection(_ url: URL, timeout: TimeInterval = 4) async throws -> Double {
        try await probeNetworkConnection(url, parameters: .tcp, timeout: timeout)
    }

    private func probeTLSConnection(_ url: URL, timeout: TimeInterval = 5) async throws -> Double {
        try await probeNetworkConnection(url, parameters: .tls, timeout: timeout)
    }

    private func probeNetworkConnection(_ url: URL, parameters: NWParameters, timeout: TimeInterval) async throws -> Double {
        guard let host = url.host else { throw APIError.invalidURL }
        let portNumber = url.port ?? (url.scheme?.lowercased() == "http" ? 80 : 443)
        guard (1...65_535).contains(portNumber),
              let port = NWEndpoint.Port(rawValue: UInt16(portNumber))
        else {
            throw APIError.invalidURL
        }

        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: parameters)
        let start = Date()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
                let box = ProbeContinuationBox(continuation)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let latencyMs = max(Date().timeIntervalSince(start) * 1000, 0.1)
                        connection.cancel()
                        box.resume(.success(latencyMs))
                    case .failed(let error):
                        connection.cancel()
                        box.resume(.failure(error))
                    case .cancelled:
                        box.resume(.failure(APIError.actionError("TLS 连接已取消")))
                    default:
                        break
                    }
                }
                connection.start(queue: .global(qos: .utility))
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    connection.cancel()
                    box.resume(.failure(APIError.actionError("TLS 连接超时")))
                }
            }
        } onCancel: {
            connection.cancel()
        }
    }

    private func isLikelyLocalProxyLatency(_ latencyMs: Double) -> Bool {
        latencyMs > 0 && latencyMs < 15
    }

    private func probeURL(_ url: URL, method: String) async throws -> HTTPURLResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 12
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        let requestSession = shouldBypassProxy(for: url) ? directSession : session
        let (_, response) = try await requestSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return http
    }

    func fetchLatestRelease(owner: String, repo: String) async throws -> CCHGitHubRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
        guard
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let htmlURLString = dict["html_url"] as? String,
            let htmlURL = URL(string: htmlURLString)
        else {
            throw APIError.parseError
        }

        let publishedAt: Date?
        if let raw = dict["published_at"] as? String {
            let iso = ISO8601DateFormatter()
            publishedAt = iso.date(from: raw)
        } else {
            publishedAt = nil
        }

        return CCHGitHubRelease(
            tag: stringValue(dict["tag_name"]),
            name: stringValue(dict["name"]),
            body: stringValue(dict["body"]),
            htmlURL: htmlURL,
            publishedAt: publishedAt
        )
    }

    private func getV1(
        config: CCHConfig,
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Any {
        try await requestJSON(config: config, url: v1URL(config: config, path: path, queryItems: queryItems), method: "GET", body: nil)
    }

    private func postV1(config: CCHConfig, path: String, body: [String: Any]) async throws -> Any {
        try await requestJSON(config: config, url: v1URL(config: config, path: path), method: "POST", body: body)
    }

    private func patchV1(config: CCHConfig, path: String, body: [String: Any]) async throws -> Any {
        try await requestJSON(config: config, url: v1URL(config: config, path: path), method: "PATCH", body: body)
    }

    private func postAction(
        config: CCHConfig,
        module: String,
        action: String,
        body: [String: Any] = [:]
    ) async throws -> Any {
        let base = try normalizedBaseURL(config)
        guard let url = URL(string: "\(base)/api/actions/\(module)/\(action)") else {
            throw APIError.invalidURL
        }
        let value = try await requestJSON(config: config, url: url, method: "POST", body: body)
        guard let dict = value as? [String: Any] else { throw APIError.parseError }
        if boolValue(dict["ok"]) {
            return dict["data"] ?? NSNull()
        }
        throw APIError.actionError(stringValue(dict["error"], fallback: "CCH 操作失败"))
    }

    private func fetchLegacyLogs(
        config: CCHConfig,
        page: Int,
        pageSize: Int,
        startDate: Date?,
        model: String,
        statusCode: String,
        sessionId: String
    ) async throws -> CCHLogsPage {
        var body: [String: Any] = [
            "page": page,
            "pageSize": pageSize
        ]
        if let startDate {
            body["startDate"] = ISO8601DateFormatter().string(from: startDate)
            body["endDate"] = ISO8601DateFormatter().string(from: Date())
        }
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedModel.isEmpty {
            body["model"] = trimmedModel
        }
        if let code = Int(statusCode.trimmingCharacters(in: .whitespacesAndNewlines)) {
            body["statusCode"] = code
        }
        let trimmedSession = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSession.isEmpty {
            body["sessionId"] = trimmedSession
        }

        let data = try await postAction(config: config, module: "usage-logs", action: "getUsageLogs", body: body)
        guard let dict = data as? [String: Any] else { throw APIError.parseError }
        let rows = itemRows(from: dict)
        let summary = dict["summary"] as? [String: Any] ?? [:]
        return CCHLogsPage(
            logs: rows.map(parseLog),
            total: intValue(dict["total"], fallback: rows.count),
            summary: CCHLogSummary(
                totalRequests: intValue(summary["totalRequests"]),
                totalCost: doubleValue(summary["totalCost"]),
                totalTokens: intValue(summary["totalTokens"]),
                inputTokens: intValue(summary["totalInputTokens"]),
                outputTokens: intValue(summary["totalOutputTokens"]),
                cacheCreationTokens: cacheCreationTokens(from: summary, prefix: "total"),
                cacheReadTokens: intValue(summary["totalCacheReadTokens"])
            )
        )
    }

    private func fetchOfficialLeaderboard(config: CCHConfig, period: String, scope: String) async throws -> [CCHLeaderboardEntry] {
        async let primaryRows = fetchOfficialLeaderboardRows(config: config, period: period, scope: scope, cacheHitMode: false)
        async let cacheRows = fetchOfficialLeaderboardRows(config: config, period: period, scope: scope, cacheHitMode: true)
        let primary = try await primaryRows
        let cache = (try? await cacheRows) ?? []
        guard !cache.isEmpty else { return primary }

        let cacheByTitle = Dictionary(cache.map { ($0.title.lowercased(), $0) }, uniquingKeysWith: mergeLeaderboardEntries)
        return primary.map { entry in
            guard let cacheEntry = cacheByTitle[entry.title.lowercased()] else { return entry }
            return entry.mergingCacheData(from: cacheEntry)
        }
    }

    private func fetchOfficialLeaderboardRows(
        config: CCHConfig,
        period: String,
        scope: String,
        cacheHitMode: Bool
    ) async throws -> [CCHLeaderboardEntry] {
        let base = try normalizedBaseURL(config)
        guard var components = URLComponents(string: base + "/api/leaderboard") else {
            throw APIError.invalidURL
        }
        let apiScope: String
        if cacheHitMode {
            switch scope {
            case "user":
                apiScope = "userCacheHitRate"
            case "provider":
                apiScope = "providerCacheHitRate"
            default:
                apiScope = scope
            }
        } else {
            apiScope = scope
        }
        components.queryItems = [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "scope", value: apiScope)
        ] + leaderboardExtraQueryItems(scope: apiScope)
        guard let url = components.url else { throw APIError.invalidURL }
        let value = try await requestJSON(config: config, url: url, method: "GET", body: nil)
        let rows = itemRows(from: value)
        return parseOfficialLeaderboardRows(rows, scope: apiScope)
    }

    private func shouldFallbackToActions(_ error: Error) -> Bool {
        switch error {
        case APIError.httpError(let code):
            return code == 404 || code == 405 || code == 410
        case APIError.parseError, APIError.invalidResponse:
            return true
        default:
            return false
        }
    }

    private func v1URL(config: CCHConfig, path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let base = try normalizedBaseURL(config)
        guard var components = URLComponents(string: base + path) else { throw APIError.invalidURL }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func requestJSON(
        config: CCHConfig,
        url: URL,
        method: String,
        body: [String: Any]?
    ) async throws -> Any {
        let token = try resolveToken(config)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(token, forHTTPHeaderField: "X-Api-Key")
        request.setValue("1", forHTTPHeaderField: "X-CCH-Dashboard-Compat")
        request.setValue("auth-token=\(token)", forHTTPHeaderField: "Cookie")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let requestSession = shouldBypassProxy(for: url) ? directSession : session
        let (data, response) = try await requestSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func resolveToken(_ config: CCHConfig) throws -> String {
        let explicit = config.token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty {
            return explicit
        }
        let path = config.envPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { throw APIError.missingToken }

        let expandedPath = (path as NSString).expandingTildeInPath
        let modifiedAt = try? FileManager.default
            .attributesOfItem(atPath: expandedPath)[.modificationDate] as? Date
        if let cachedToken, cachedToken.path == expandedPath, cachedToken.modifiedAt == modifiedAt {
            return cachedToken.token
        }

        let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
        let tokenKeys = Set(["CCH_API_KEY", "CCH_TOKEN", "API_KEY", "AUTH_TOKEN", "TOKEN", "KEY"])
        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if let eq = line.firstIndex(of: "=") {
                let key = line[..<eq].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
                if tokenKeys.contains(key.uppercased()), !value.isEmpty {
                    let token = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    cachedToken = (expandedPath, modifiedAt, token)
                    return token
                }
            } else {
                let token = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                cachedToken = (expandedPath, modifiedAt, token)
                return token
            }
        }
        throw APIError.missingToken
    }

    private func normalizedBaseURL(_ config: CCHConfig) throws -> String {
        let trimmed = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard URL(string: trimmed) != nil else { throw APIError.invalidURL }
        return trimmed
    }

    private func parseLog(_ row: [String: Any]) -> CCHLogEntry {
        let chainRows = row["providerChain"] as? [[String: Any]] ?? []
        let isFastTier = isFastTierLog(row)
        return CCHLogEntry(
            id: intValue(row["id"]),
            createdAt: stringValue(row["createdAt"]),
            sessionId: stringValue(row["sessionId"]),
            requestSequence: intValue(row["requestSequence"]),
            userName: stringValue(row["userName"]),
            keyName: stringValue(row["keyName"]),
            providerName: stringValue(row["providerName"]),
            model: stringValue(row["model"]),
            originalModel: stringValue(row["originalModel"]),
            endpoint: stringValue(row["endpoint"]),
            statusCode: optionalInt(row["statusCode"]),
            messagesCount: intValue(row["messagesCount"]),
            inputTokens: intValue(row["inputTokens"]),
            outputTokens: intValue(row["outputTokens"]),
            totalTokens: intValue(row["totalTokens"]),
            cacheCreationTokens: cacheCreationTokens(from: row),
            cacheReadTokens: intValue(row["cacheReadInputTokens"]),
            costUsd: doubleValue(row["costUsd"]),
            durationMs: optionalInt(row["durationMs"]),
            ttfbMs: optionalInt(row["ttfbMs"]),
            tokensPerSecond: optionalDouble(row["tokensPerSecond"]) ?? optionalDouble(row["tokensPerSecondTokens"]) ?? optionalDouble(row["outputTokensPerSecond"]),
            costMultiplier: logCostMultiplier(row, chainRows: chainRows),
            isFastTier: isFastTier,
            errorMessage: stringValue(row["errorMessage"]),
            providerChain: chainRows.map {
                CCHProviderChainItem(
                    name: stringValue($0["name"], fallback: "Provider"),
                    providerType: stringValue($0["providerType"]),
                    reason: stringValue($0["reason"]),
                    circuitState: stringValue($0["circuitState"]),
                    priority: intValue($0["priority"]),
                    weight: intValue($0["weight"]),
                    groupTag: stringValue($0["groupTag"]),
                    costMultiplier: doubleValue($0["costMultiplier"], fallback: 1),
                    statusCode: optionalInt($0["statusCode"]),
                    attemptNumber: optionalInt($0["attemptNumber"]),
                    errorMessage: stringValue($0["errorMessage"])
                )
            }
        )
    }

    private func shouldBypassProxy(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host == "localhost" || host.hasSuffix(".local") { return true }
        if host.hasPrefix("10.") || host.hasPrefix("192.168.") { return true }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            if parts[0] == 127 { return true }
            if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        }
        return false
    }
}

private final class ProbeContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Double, Error>?

    init(_ continuation: CheckedContinuation<Double, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<Double, Error>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        guard let continuation else { return }
        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private func stringValue(_ value: Any?, fallback: String = "") -> String {
    switch value {
    case let s as String: return s
    case let n as NSNumber: return n.stringValue
    default: return fallback
    }
}

private func firstStringValue(_ row: [String: Any], keys: [String], fallback: String = "") -> String {
    for key in keys {
        let value = stringValue(row[key]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            return value
        }
    }
    return fallback
}

private func stringDictionary(_ value: Any?) -> [String: String]? {
    if let dict = value as? [String: String] {
        return dict
    }
    guard let dict = value as? [String: Any] else { return nil }
    let mapped = dict.reduce(into: [String: String]()) { partial, item in
        let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = stringValue(item.value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !value.isEmpty else { return }
        partial[key] = value
    }
    return mapped.isEmpty ? nil : mapped
}

private func providerCustomHeaders(_ row: [String: Any]) -> [String: String]? {
    guard let headers = stringDictionary(row["customHeaders"] ?? row["custom_headers"]) else {
        return nil
    }
    let filtered = headers.filter { _, value in
        !value.contains("[REDACTED]")
    }
    return filtered.isEmpty ? nil : filtered
}

private func intValue(_ value: Any?, fallback: Int = 0) -> Int {
    switch value {
    case let n as Int: return n
    case let n as Int64: return Int(n)
    case let n as Double: return Int(n)
    case let n as NSNumber: return n.intValue
    case let s as String: return Int(Double(s) ?? Double(fallback))
    default: return fallback
    }
}

private func optionalInt(_ value: Any?) -> Int? {
    if value == nil || value is NSNull { return nil }
    return intValue(value)
}

private func firstOptionalInt(_ row: [String: Any], keys: [String]) -> Int? {
    for key in keys {
        if let value = optionalInt(row[key]) {
            return value
        }
    }
    return nil
}

private func optionalDouble(_ value: Any?) -> Double? {
    if value == nil || value is NSNull { return nil }
    return doubleValue(value)
}

private func firstOptionalDouble(_ row: [String: Any], keys: [String]) -> Double? {
    for key in keys {
        if let value = optionalDouble(row[key]) {
            return value
        }
    }
    return nil
}

private func doubleValue(_ value: Any?, fallback: Double = 0) -> Double {
    switch value {
    case let n as Double: return n
    case let n as Int: return Double(n)
    case let n as NSNumber: return n.doubleValue
    case let s as String: return Double(s) ?? fallback
    default: return fallback
    }
}

private func boolValue(_ value: Any?, fallback: Bool = false) -> Bool {
    switch value {
    case let b as Bool: return b
    case let n as NSNumber: return n.boolValue
    case let s as String: return ["true", "1", "yes"].contains(s.lowercased())
    default: return fallback
    }
}

private func isEndpointEnabled(_ row: [String: Any]) -> Bool {
    for key in ["isEnabled", "enabled"] where row[key] != nil {
        return boolValue(row[key])
    }
    return true
}

private func logCostMultiplier(_ row: [String: Any], chainRows: [[String: Any]]) -> Double {
    if let value = costBreakdownDouble(row, keys: ["provider_multiplier", "providerMultiplier"]) {
        return value
    }
    return optionalDouble(row["costMultiplier"])
        ?? providerChainMultiplier(chainRows: chainRows, providerName: stringValue(row["providerName"]))
}

private func costBreakdownDouble(_ row: [String: Any], keys: [String]) -> Double? {
    guard let breakdown = row["costBreakdown"] as? [String: Any] else { return nil }
    return firstOptionalDouble(breakdown, keys: keys)
}

private func serviceTierSetting(_ value: Any?, type targetType: String) -> [String: Any]? {
    switch value {
    case let settings as [[String: Any]]:
        return settings.first { stringValue($0["type"]).lowercased() == targetType }
    case let setting as [String: Any]:
        if stringValue(setting["type"]).lowercased() == targetType {
            return setting
        }
        for nested in setting.values {
            if let match = serviceTierSetting(nested, type: targetType) {
                return match
            }
        }
        return nil
    case let values as [Any]:
        for item in values {
            if let match = serviceTierSetting(item, type: targetType) {
                return match
            }
        }
        return nil
    case let raw as String:
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }
        return serviceTierSetting(json, type: targetType)
    default:
        return nil
    }
}

private func isFastTierLog(_ row: [String: Any]) -> Bool {
    if let setting = serviceTierSetting(row["specialSettings"], type: "codex_service_tier_result") {
        return boolValue(setting["effectivePriority"])
    }

    let boolKeys = [
        "isFastTier",
        "fastTier",
        "isPriorityTier",
        "priorityServiceTier"
    ]
    for key in boolKeys where row[key] != nil {
        return boolValue(row[key])
    }

    if row["statusCode"] == nil || row["statusCode"] is NSNull {
        return hasPendingPriorityServiceTier(row["specialSettings"])
    }

    return false
}

private func hasPendingPriorityServiceTier(_ value: Any?) -> Bool {
    switch value {
    case let settings as [[String: Any]]:
        return settings.contains(where: hasPendingPriorityServiceTier)
    case let setting as [String: Any]:
        let type = stringValue(setting["type"]).lowercased()
        guard type == "provider_parameter_override" else {
            return setting.values.contains(where: hasPendingPriorityServiceTier)
        }

        if let changes = setting["changes"] as? [[String: Any]] {
            return changes.contains { change in
                let path = stringValue(change["path"]).lowercased()
                guard path == "service_tier" || path == "service-tier" || path == "servicetier" else {
                    return false
                }
                return isPriorityServiceTierText(stringValue(change["after"]))
                    || isPriorityServiceTierText(stringValue(change["value"]))
            }
        }
        return isPriorityServiceTierText(firstStringValue(
            setting,
            keys: ["serviceTier", "service_tier", "requestedServiceTier", "value", "after"]
        ))
    case let values as [Any]:
        return values.contains(where: hasPendingPriorityServiceTier)
    case let raw as String:
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data)
        else {
            return false
        }
        return hasPendingPriorityServiceTier(json)
    default:
        return false
    }
}

private func isPriorityServiceTierText(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "priority"
        || normalized == "fast"
        || normalized == "service_tier:priority"
        || normalized == "service-tier:priority"
}

private func providerChainMultiplier(chainRows: [[String: Any]], providerName: String) -> Double {
    if let item = chainRows.reversed().first(where: { stringValue($0["name"]) == providerName }) {
        return doubleValue(item["costMultiplier"], fallback: 1)
    }
    if let item = chainRows.last {
        return doubleValue(item["costMultiplier"], fallback: 1)
    }
    return 1
}

private func optionalCacheHitRate(_ row: [String: Any]) -> Double? {
    let keys = [
        "cacheHitRate",
        "cacheHitRatio",
        "cacheReadRate",
        "cacheRate",
        "cacheHitPercentage"
    ]
    for key in keys {
        guard let raw = optionalDouble(row[key]) else { continue }
        let normalized = raw > 1 ? raw / 100 : raw
        return min(1, max(0, normalized))
    }
    return nil
}

private func parseProviderGroup(_ value: String) -> CCHProviderGroup? {
    let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }
    return CCHProviderGroup(id: name, name: name, providerCount: nil, costMultiplier: nil)
}

private func parseProviderGroup(_ row: [String: Any]) -> CCHProviderGroup? {
    let name = firstStringValue(row, keys: ["name", "group", "groupTag", "group_tag", "title"], fallback: "默认")
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return nil }
    let id = firstStringValue(row, keys: ["id", "name", "group", "groupTag", "group_tag"], fallback: trimmedName)
    return CCHProviderGroup(
        id: id,
        name: trimmedName,
        providerCount: firstOptionalInt(row, keys: ["providerCount", "count"]),
        costMultiplier: firstOptionalDouble(row, keys: ["costMultiplier", "cost_multiplier"])
    )
}

private func providerGroupStringRows(from value: Any) -> [String]? {
    if let rows = value as? [String] {
        return rows
    }
    guard let dict = value as? [String: Any] else { return nil }
    for key in ["items", "groups", "data"] {
        if let rows = dict[key] as? [String] {
            return rows
        }
    }
    if let data = dict["data"] as? [String: Any] {
        return providerGroupStringRows(from: data)
    }
    return nil
}

private func normalizedCacheHitRate(cacheReadTokens: Int, cacheCreationTokens: Int, inputTokens: Int) -> Double? {
    let totalCacheableInput = inputTokens + cacheCreationTokens + cacheReadTokens
    guard totalCacheableInput > 0 else { return nil }
    return min(1, max(0, Double(cacheReadTokens) / Double(totalCacheableInput)))
}

private func itemRows(from value: Any) -> [[String: Any]] {
    if let rows = value as? [[String: Any]] {
        return rows
    }
    guard let dict = value as? [String: Any] else { return [] }
    for key in ["items", "logs", "data", "groups"] {
        if let rows = dict[key] as? [[String: Any]] {
            return rows
        }
    }
    if let data = dict["data"] as? [String: Any] {
        return itemRows(from: data)
    }
    return []
}

private func usageLogTotalPages(from value: Any) -> Int {
    guard let dict = value as? [String: Any] else { return 1 }
    let pageInfo = dict["pageInfo"] as? [String: Any] ?? [:]
    return max(1, intValue(pageInfo["totalPages"], fallback: 1))
}

private func parseActiveSession(_ row: [String: Any]) -> CCHActiveSession {
    CCHActiveSession(
        sessionId: stringValue(row["sessionId"]),
        providerId: intValue(row["providerId"]),
        userName: stringValue(row["userName"]),
        keyName: stringValue(row["keyName"]),
        providerName: stringValue(row["providerName"]),
        model: stringValue(row["model"]),
        apiType: stringValue(row["apiType"]),
        startTime: intValue(row["startTime"]),
        inputTokens: intValue(row["inputTokens"]),
        outputTokens: intValue(row["outputTokens"]),
        totalTokens: intValue(row["totalTokens"]),
        costUsd: doubleValue(row["costUsd"]),
        durationMs: intValue(row["durationMs"]),
        requestCount: intValue(row["requestCount"]),
        concurrentCount: intValue(row["concurrentCount"]),
        status: stringValue(row["status"])
    )
}

private func usageLogQueryItems(
    page: Int,
    pageSize: Int,
    startDate: Date?,
    model: String,
    statusCode: String,
    sessionId: String
) -> [URLQueryItem] {
    var queryItems = [
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "pageSize", value: "\(pageSize)")
    ]
    if let startDate {
        queryItems.append(URLQueryItem(name: "startTime", value: "\(Int(startDate.timeIntervalSince1970 * 1000))"))
        queryItems.append(URLQueryItem(name: "endTime", value: "\(Int(Date().timeIntervalSince1970 * 1000))"))
    }
    let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedModel.isEmpty {
        queryItems.append(URLQueryItem(name: "model", value: trimmedModel))
    }
    let trimmedStatus = statusCode.trimmingCharacters(in: .whitespacesAndNewlines)
    if Int(trimmedStatus) != nil {
        queryItems.append(URLQueryItem(name: "statusCode", value: trimmedStatus))
    }
    let trimmedSession = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedSession.isEmpty {
        queryItems.append(URLQueryItem(name: "sessionId", value: trimmedSession))
    }
    return queryItems
}

private func cacheCreationTokens(from row: [String: Any], prefix: String = "") -> Int {
    let keyPrefix = prefix.isEmpty ? "" : prefix
    let capitalizedPrefix = keyPrefix.isEmpty ? "" : keyPrefix
    return intValue(row["\(capitalizedPrefix)CacheCreationTokens"])
        + intValue(row["\(capitalizedPrefix)CacheCreation1hTokens"])
        + intValue(row["\(capitalizedPrefix)CacheCreation5mTokens"])
        + intValue(row["cacheCreationInputTokens"])
        + intValue(row["cacheCreation1hInputTokens"])
        + intValue(row["cacheCreation5mInputTokens"])
}

private func leaderboardStartDate(_ period: String) -> Date? {
    let calendar = Calendar.current
    switch period {
    case "daily":
        return calendar.startOfDay(for: Date())
    case "weekly":
        return calendar.dateInterval(of: .weekOfYear, for: Date())?.start
    case "monthly":
        return calendar.dateInterval(of: .month, for: Date())?.start
    default:
        return nil
    }
}

private func aggregateLeaderboard(rows: [[String: Any]], scope: String) -> [CCHLeaderboardEntry] {
    let entries = rows.reduce(into: [String: CCHLeaderboardEntry]()) { result, row in
        let title: String
        let subtitle: String
        let id: String
        switch scope {
        case "provider":
            title = stringValue(row["providerName"], fallback: "Provider")
            subtitle = "provider"
            let providerId = intValue(row["providerId"])
            id = providerId > 0 ? "provider-\(providerId)" : "provider-\(title.lowercased())"
        case "model":
            title = stringValue(row["model"], fallback: stringValue(row["originalModel"], fallback: "Model"))
            subtitle = "model"
            id = "model-\(title.lowercased())"
        default:
            title = stringValue(row["userName"], fallback: "User")
            subtitle = "user"
            let userId = intValue(row["userId"])
            id = userId > 0 ? "user-\(userId)" : "user-\(title.lowercased())"
        }

        let entry = CCHLeaderboardEntry(
            id: id,
            title: title,
            subtitle: subtitle,
            requests: 1,
            cost: doubleValue(row["costUsd"]),
            tokens: intValue(row["totalTokens"]),
            inputTokens: intValue(row["inputTokens"]),
            cacheCreationTokens: cacheCreationTokens(from: row),
            cacheReadTokens: intValue(row["cacheReadInputTokens"]),
            cacheHitRateOverride: nil,
            successRate: nil,
            modelStats: []
        )
        result[id] = result[id].map { mergeLeaderboardEntries($0, entry) } ?? entry
    }
    return entries.values.sorted {
        if $0.cost != $1.cost { return $0.cost > $1.cost }
        if $0.tokens != $1.tokens { return $0.tokens > $1.tokens }
        return $0.requests > $1.requests
    }
}

private func leaderboardStableId(_ row: [String: Any], scope: String, title: String) -> String {
    switch scope {
    case "provider", "providerCacheHitRate":
        let providerId = intValue(row["providerId"])
        return providerId > 0 ? "provider-\(providerId)" : "provider-\(title.lowercased())"
    case "user", "userCacheHitRate":
        let userId = intValue(row["userId"])
        return userId > 0 ? "user-\(userId)" : "user-\(title.lowercased())"
    case "model":
        return "model-\(title.lowercased())"
    default:
        return title.lowercased()
    }
}

private func leaderboardExtraQueryItems(scope: String) -> [URLQueryItem] {
    switch scope {
    case "user", "userCacheHitRate":
        return [URLQueryItem(name: "includeUserModelStats", value: "1")]
    case "provider":
        return [URLQueryItem(name: "includeModelStats", value: "1")]
    default:
        return []
    }
}

private func parseOfficialLeaderboardRows(_ rows: [[String: Any]], scope: String) -> [CCHLeaderboardEntry] {
    rows.map { row in
        let title: String
        let subtitle: String
        switch scope {
        case "providerCacheHitRate":
            title = stringValue(row["providerName"], fallback: "Provider")
            subtitle = "缓存命中榜"
        case "userCacheHitRate":
            title = stringValue(row["userName"], fallback: "User")
            subtitle = "缓存命中榜"
        case "provider":
            title = stringValue(row["providerName"], fallback: "Provider")
            subtitle = String(format: "success %.1f%%", doubleValue(row["successRate"]) * 100)
        case "model":
            title = stringValue(row["model"], fallback: "Model")
            subtitle = "model"
        default:
            title = stringValue(row["userName"], fallback: "User")
            subtitle = "user"
        }

        let stableId = leaderboardStableId(row, scope: scope, title: title)
        let totalTokens = intValue(row["totalTokens"], fallback: intValue(row["totalInputTokens"]))
        let cacheReadTokens = intValue(row["cacheReadTokens"])
        let cacheCreationTokens = intValue(row["cacheCreationTokens"])
        let totalInputTokens = intValue(row["totalInputTokens"], fallback: totalTokens)

        return CCHLeaderboardEntry(
            id: stableId,
            title: title,
            subtitle: subtitle,
            requests: intValue(row["totalRequests"]),
            cost: doubleValue(row["totalCost"]),
            tokens: totalTokens,
            inputTokens: totalInputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cacheHitRateOverride: scope == "user" || scope == "provider" || scope == "model"
                ? nil
                : optionalCacheHitRate(row),
            successRate: row["successRate"] == nil ? nil : doubleValue(row["successRate"]),
            modelStats: parseLeaderboardModelStats(row["modelStats"], parentId: stableId)
        )
    }
}

private func parseLeaderboardModelStats(_ value: Any?, parentId: String) -> [CCHLeaderboardModelStat] {
    guard let rows = value as? [[String: Any]] else { return [] }
    let parsed: [CCHLeaderboardModelStat] = rows.compactMap { row -> CCHLeaderboardModelStat? in
        let model = stringValue(row["model"], fallback: "Model")
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let totalInputTokens = intValue(row["totalInputTokens"], fallback: intValue(row["totalTokens"]))
        let cacheReadTokens = intValue(row["cacheReadTokens"])
        let cacheCreationTokens = intValue(row["cacheCreationTokens"])
        return CCHLeaderboardModelStat(
            id: "\(parentId)-model-\(model.lowercased())",
            model: model,
            requests: intValue(row["totalRequests"]),
            cost: doubleValue(row["totalCost"]),
            tokens: intValue(row["totalTokens"], fallback: totalInputTokens),
            inputTokens: totalInputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cacheHitRateOverride: optionalCacheHitRate(row)
        )
    }
    return Dictionary<String, CCHLeaderboardModelStat>(
        parsed.map { ($0.model.lowercased(), $0) },
        uniquingKeysWith: mergeLeaderboardModelStat
    )
        .values
        .sorted { lhs, rhs in
            if lhs.cost != rhs.cost { return lhs.cost > rhs.cost }
            return lhs.requests > rhs.requests
        }
}

private func mergeLeaderboardModelStats(
    primary: [CCHLeaderboardModelStat],
    cache: [CCHLeaderboardModelStat]
) -> [CCHLeaderboardModelStat] {
    guard !cache.isEmpty else { return primary }
    let cacheByModel = Dictionary(cache.map { ($0.model.lowercased(), $0) }, uniquingKeysWith: mergeLeaderboardModelStat)
    if primary.isEmpty { return cache }
    return primary.map { stat in
        guard let cacheStat = cacheByModel[stat.model.lowercased()] else { return stat }
        return CCHLeaderboardModelStat(
            id: stat.id,
            model: stat.model,
            requests: stat.requests,
            cost: stat.cost,
            tokens: stat.tokens,
            inputTokens: cacheStat.inputTokens > 0 ? cacheStat.inputTokens : stat.inputTokens,
            cacheCreationTokens: cacheStat.inputTokens > 0 || cacheStat.cacheHitRateOverride != nil ? cacheStat.cacheCreationTokens : stat.cacheCreationTokens,
            cacheReadTokens: cacheStat.inputTokens > 0 || cacheStat.cacheHitRateOverride != nil ? cacheStat.cacheReadTokens : stat.cacheReadTokens,
            cacheHitRateOverride: cacheStat.cacheHitRateOverride ?? stat.cacheHitRateOverride
        )
    }
}

private func mergeLeaderboardEntries(_ lhs: CCHLeaderboardEntry, _ rhs: CCHLeaderboardEntry) -> CCHLeaderboardEntry {
    CCHLeaderboardEntry(
        id: lhs.id,
        title: lhs.title,
        subtitle: lhs.subtitle,
        requests: lhs.requests + rhs.requests,
        cost: lhs.cost + rhs.cost,
        tokens: lhs.tokens + rhs.tokens,
        inputTokens: lhs.inputTokens + rhs.inputTokens,
        cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
        cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
        cacheHitRateOverride: rhs.cacheHitRateOverride ?? lhs.cacheHitRateOverride,
        successRate: lhs.successRate ?? rhs.successRate,
        modelStats: mergeLeaderboardModelStats(primary: lhs.modelStats, cache: rhs.modelStats)
    )
}

private func mergeLeaderboardModelStat(_ lhs: CCHLeaderboardModelStat, _ rhs: CCHLeaderboardModelStat) -> CCHLeaderboardModelStat {
    CCHLeaderboardModelStat(
        id: lhs.id,
        model: lhs.model,
        requests: lhs.requests + rhs.requests,
        cost: lhs.cost + rhs.cost,
        tokens: lhs.tokens + rhs.tokens,
        inputTokens: lhs.inputTokens + rhs.inputTokens,
        cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
        cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
        cacheHitRateOverride: rhs.cacheHitRateOverride ?? lhs.cacheHitRateOverride
    )
}

private func compactArrayDescription(_ value: Any?) -> String {
    if let strings = value as? [String] {
        return strings.isEmpty ? "all" : strings.prefix(4).joined(separator: ", ")
    }
    if let rows = value as? [[String: Any]] {
        return rows.isEmpty ? "none" : "\(rows.count) rules"
    }
    if let rows = value as? [Any] {
        return rows.isEmpty ? "none" : "\(rows.count) items"
    }
    return "none"
}

private func preferredProviderTestModel(_ row: [String: Any], providerType: String) -> String {
    providerTestModelOptions(row, providerType: providerType).first ?? defaultProviderTestModel(providerType)
}

private func providerTestModelOptions(_ row: [String: Any], providerType: String) -> [String] {
    var values = allowedExactModels(row["allowedModels"] ?? row["allowed_models"])
    let lastCallModel = stringValue(row["lastCallModel"]).trimmingCharacters(in: .whitespacesAndNewlines)
    if !lastCallModel.isEmpty {
        values.append(lastCallModel)
    }
    values.append(defaultProviderTestModel(providerType))
    return uniqueTrimmedStrings(values)
}

private func allowedExactModels(_ value: Any?) -> [String] {
    if let strings = value as? [String] {
        return uniqueTrimmedStrings(strings)
    }
    if let rows = value as? [[String: Any]] {
        var values: [String] = []
        for row in rows {
            let matchType = stringValue(row["matchType"] ?? row["match_type"]).lowercased()
            guard matchType.isEmpty || matchType == "exact" else { continue }
            let model = firstStringValue(row, keys: ["pattern", "model", "name", "value"])
            if !model.isEmpty {
                values.append(model)
            }
        }
        return uniqueTrimmedStrings(values)
    }
    let raw = stringValue(value).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty, raw != "all", raw != "none" else { return [] }
    return [raw]
}

private func uniqueTrimmedStrings(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for value in values {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        let key = trimmed.lowercased()
        guard !seen.contains(key) else { continue }
        seen.insert(key)
        result.append(trimmed)
    }
    return result
}

private func defaultProviderTestModel(_ providerType: String) -> String {
    switch normalizedProviderType(providerType) {
    case "codex":
        return "gpt-5.5"
    case "openai-compatible":
        return "gpt-4.1-mini"
    case "gemini", "gemini-cli":
        return "gemini-2.5-flash"
    default:
        return "claude-haiku-4-5-20251001"
    }
}

private func normalizedProviderType(_ providerType: String) -> String {
    let normalized = providerType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized.isEmpty ? "claude" : normalized
}

private func providerModelTestTimeoutMs(_ providerType: String) -> Int {
    let normalized = normalizedProviderType(providerType)
    return normalized == "gemini" || normalized == "gemini-cli" ? 60_000 : 15_000
}

private func normalizedTestModel(_ model: String?) -> String? {
    guard let model else { return nil }
    let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
}

private func normalizedProviderTestURL(_ value: String) -> String? {
    let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    let normalized = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? raw : "https://\(raw)"
    guard let url = URL(string: normalized),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          url.host != nil
    else {
        return nil
    }
    return url.absoluteString
}

private func buildLimitText(_ row: [String: Any]) -> String {
    var pieces: [String] = []
    let daily = doubleValue(row["limitDailyUsd"])
    let total = doubleValue(row["limitTotalUsd"])
    let rpm = intValue(row["rpm"])
    if daily > 0 { pieces.append(String(format: "日 $%.0f", daily)) }
    if total > 0 { pieces.append(String(format: "总 $%.0f", total)) }
    if rpm > 0 { pieces.append("RPM \(rpm)") }
    return pieces.isEmpty ? "无限制" : pieces.joined(separator: " · ")
}
