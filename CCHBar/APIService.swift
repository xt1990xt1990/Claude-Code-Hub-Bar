import Foundation

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

struct CCHLeaderboardModelStat: Identifiable {
    let id: String
    let model: String
    let requests: Int
    let cost: Double
    let tokens: Int
    let inputTokens: Int
    let cacheReadTokens: Int
    let cacheHitRateOverride: Double?

    var cacheHitRate: Double? {
        if let cacheHitRateOverride { return cacheHitRateOverride }
        guard inputTokens > 0 else { return nil }
        return Double(cacheReadTokens) / Double(inputTokens)
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
    let cacheReadTokens: Int
    let cacheHitRateOverride: Double?
    let successRate: Double?
    let modelStats: [CCHLeaderboardModelStat]

    var cacheHitRate: Double? {
        if let cacheHitRateOverride { return cacheHitRateOverride }
        guard inputTokens > 0 else { return nil }
        return Double(cacheReadTokens) / Double(inputTokens)
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
            cacheReadTokens: cache.inputTokens > 0 || cache.cacheHitRateOverride != nil ? cache.cacheReadTokens : cacheReadTokens,
            cacheHitRateOverride: cache.cacheHitRate ?? cacheHitRateOverride,
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
    let limitText: String
    let health: CCHProviderHealth
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
    let latencyMs: Int?
    let errorMessage: String
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
        case .actionError(let message): return message
        }
    }
}

actor APIService {
    private let session: URLSession
    private let directSession: URLSession

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
        let data = try await getV1(config: config, path: "/api/v1/dashboard/overview")
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
        let data = try await getV1(
            config: config,
            path: "/api/v1/sessions",
            queryItems: [
                URLQueryItem(name: "state", value: "active"),
                URLQueryItem(name: "pageSize", value: "100")
            ]
        )
        return itemRows(from: data).map(parseActiveSession)
    }

    func fetchLeaderboard(
        config: CCHConfig,
        period: String,
        scope: String,
        cacheHitMode: Bool = false
    ) async throws -> [CCHLeaderboardEntry] {
        _ = cacheHitMode
        let rows = try await fetchUsageLogRowsForLeaderboard(config: config, period: period)
        return aggregateLeaderboard(rows: rows, scope: scope)
    }

    private func fetchUsageLogRowsForLeaderboard(config: CCHConfig, period: String) async throws -> [[String: Any]] {
        let queryItems = usageLogQueryItems(
            page: 1,
            pageSize: 100,
            startDate: leaderboardStartDate(period),
            model: "",
            statusCode: "",
            sessionId: ""
        )
        let data = try await getV1(config: config, path: "/api/v1/usage-logs", queryItems: queryItems)
        return itemRows(from: data)
    }

    func fetchLogs(
        config: CCHConfig,
        page: Int,
        pageSize: Int,
        startDate: Date?,
        model: String,
        statusCode: String,
        sessionId: String
    ) async throws -> CCHLogsPage {
        let queryItems = usageLogQueryItems(
            page: page,
            pageSize: pageSize,
            startDate: startDate,
            model: model,
            statusCode: statusCode,
            sessionId: sessionId
        )
        let data = try await getV1(config: config, path: "/api/v1/usage-logs", queryItems: queryItems)
        guard let dict = data as? [String: Any] else { throw APIError.parseError }
        let rows = itemRows(from: dict)
        let stats = (try? await getV1(config: config, path: "/api/v1/usage-logs/stats", queryItems: queryItems)) as? [String: Any] ?? [:]
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

    func fetchProviders(config: CCHConfig) async throws -> [CCHProvider] {
        let providersData = try await getV1(config: config, path: "/api/v1/providers")
        let healthData = try? await getV1(config: config, path: "/api/v1/providers/health")
        let rows = itemRows(from: providersData)
        let healthMap = healthData as? [String: Any] ?? [:]

        return rows.map { row in
            let id = intValue(row["id"])
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
                name: stringValue(row["name"], fallback: "Provider"),
                providerType: stringValue(row["providerType"]),
                vendorId: optionalInt(row["providerVendorId"]),
                apiURL: stringValue(row["url"]),
                websiteURL: stringValue(row["websiteUrl"]),
                isEnabled: boolValue(row["isEnabled"]),
                priority: intValue(row["priority"]),
                weight: intValue(row["weight"]),
                groupTag: stringValue(row["groupTag"], fallback: "default"),
                costMultiplier: doubleValue(row["costMultiplier"], fallback: 1),
                todayCalls: intValue(row["todayCallCount"]),
                todayCost: doubleValue(row["todayTotalCostUsd"]),
                lastCallTime: stringValue(row["lastCallTime"]),
                lastCallModel: stringValue(row["lastCallModel"]),
                allowedModels: compactArrayDescription(row["allowedModels"]),
                allowedClients: compactArrayDescription(row["allowedClients"]),
                modelRedirects: compactArrayDescription(row["modelRedirects"]),
                limitText: buildLimitText(row),
                health: health
            )
        }
    }

    func setProviderEnabled(config: CCHConfig, providerId: Int, enabled: Bool) async throws {
        _ = try await patchV1(config: config, path: "/api/v1/providers/\(providerId)", body: ["is_enabled": enabled])
    }

    func resetProviderCircuit(config: CCHConfig, providerId: Int) async throws {
        _ = try await postV1(config: config, path: "/api/v1/providers/\(providerId)/circuit:reset", body: [:])
    }

    func probeFirstEndpoint(config: CCHConfig, provider: CCHProvider) async throws -> CCHProbeResult {
        guard let vendorId = provider.vendorId else {
            throw APIError.actionError("这个 Provider 没有可测速的 Vendor")
        }
        let endpointsData = try await getV1(
            config: config,
            path: "/api/v1/provider-vendors/\(vendorId)/endpoints",
            queryItems: [
                URLQueryItem(name: "providerType", value: provider.providerType),
                URLQueryItem(name: "dashboard", value: "true")
            ]
        )
        let rows = itemRows(from: endpointsData)
        guard let endpoint = rows.first(where: { boolValue($0["isEnabled"]) }) ?? rows.first else {
            throw APIError.actionError("没有可测速的端点")
        }

        let endpointId = intValue(endpoint["id"])
        let data = try await postV1(
            config: config,
            path: "/api/v1/provider-endpoints/\(endpointId):probe",
            body: ["timeoutMs": 12000]
        )
        guard let dict = data as? [String: Any] else { throw APIError.parseError }
        let result = dict["result"] as? [String: Any] ?? dict

        return CCHProbeResult(
            ok: boolValue(result["ok"]),
            method: stringValue(result["method"]),
            statusCode: optionalInt(result["statusCode"]),
            latencyMs: optionalInt(result["latencyMs"]),
            errorMessage: stringValue(result["errorMessage"])
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

        let content = try String(contentsOfFile: (path as NSString).expandingTildeInPath, encoding: .utf8)
        let tokenKeys = Set(["CCH_API_KEY", "CCH_TOKEN", "API_KEY", "AUTH_TOKEN", "TOKEN", "KEY"])
        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if let eq = line.firstIndex(of: "=") {
                let key = line[..<eq].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
                if tokenKeys.contains(key.uppercased()), !value.isEmpty {
                    return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            } else {
                return line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
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
            isFastTier: isFastTierLog(row),
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

private func stringValue(_ value: Any?, fallback: String = "") -> String {
    switch value {
    case let s as String: return s
    case let n as NSNumber: return n.stringValue
    default: return fallback
    }
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

private func optionalDouble(_ value: Any?) -> Double? {
    if value == nil || value is NSNull { return nil }
    return doubleValue(value)
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

private func isFastTierLog(_ row: [String: Any]) -> Bool {
    let boolKeys = [
        "isFastTier",
        "fastTier",
        "isPriorityTier",
        "priorityServiceTier"
    ]
    if boolKeys.contains(where: { boolValue(row[$0]) }) {
        return true
    }

    let tierKeys = [
        "serviceTier",
        "service_tier",
        "requestedServiceTier",
        "resolvedServiceTier",
        "codexServiceTier",
        "codexServiceTierPreference",
        "openaiServiceTier"
    ]
    if tierKeys.contains(where: { isFastTierText(stringValue(row[$0])) }) {
        return true
    }

    return hasPriorityServiceTierSpecialSetting(row["specialSettings"])
}

private func hasPriorityServiceTierSpecialSetting(_ value: Any?) -> Bool {
    switch value {
    case let settings as [[String: Any]]:
        return settings.contains(where: hasPriorityServiceTierSpecialSetting)
    case let setting as [String: Any]:
        let type = stringValue(setting["type"]).lowercased()
        if type == "codex_service_tier_result" || type.contains("service_tier") || type.contains("service-tier") {
            let tierValues = [
                stringValue(setting["requestedServiceTier"]),
                stringValue(setting["serviceTier"]),
                stringValue(setting["resolvedServiceTier"]),
                stringValue(setting["service_tier"]),
                stringValue(setting["value"]),
                stringValue(setting["after"])
            ]
            if tierValues.contains(where: isFastTierText) {
                return true
            }
        }

        if let changes = setting["changes"] as? [[String: Any]],
           changes.contains(where: isFastTierChange) {
            return true
        }

        return setting.values.contains(where: hasPriorityServiceTierSpecialSetting)
    case let values as [Any]:
        return values.contains(where: hasPriorityServiceTierSpecialSetting)
    case let raw as String:
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) {
            return hasPriorityServiceTierSpecialSetting(json)
        }
        let lower = trimmed.lowercased()
        return (lower.contains("service_tier") || lower.contains("service-tier") || lower.contains("servicetier"))
            && (lower.contains("priority") || lower.contains("fast"))
    default:
        return false
    }
}

private func isFastTierChange(_ change: [String: Any]) -> Bool {
    let path = stringValue(change["path"]).lowercased()
    guard path == "service_tier" || path == "service-tier" || path == "servicetier" else {
        return false
    }
    return isFastTierText(stringValue(change["after"]))
        || isFastTierText(stringValue(change["value"]))
}

private func isFastTierText(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "priority"
        || normalized == "fast"
        || normalized == "service_tier:priority"
        || normalized == "service-tier:priority"
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
        return raw > 1 ? raw / 100 : raw
    }
    return nil
}

private func itemRows(from value: Any) -> [[String: Any]] {
    if let rows = value as? [[String: Any]] {
        return rows
    }
    guard let dict = value as? [String: Any] else { return [] }
    for key in ["items", "logs", "data"] {
        if let rows = dict[key] as? [[String: Any]] {
            return rows
        }
    }
    if let data = dict["data"] as? [String: Any] {
        return itemRows(from: data)
    }
    return []
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

private func parseLeaderboardModelStats(_ value: Any?, parentId: String) -> [CCHLeaderboardModelStat] {
    guard let rows = value as? [[String: Any]] else { return [] }
    let parsed: [CCHLeaderboardModelStat] = rows.compactMap { row -> CCHLeaderboardModelStat? in
        let model = stringValue(row["model"], fallback: "Model")
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let totalInputTokens = intValue(row["totalInputTokens"])
            + intValue(row["inputTokens"])
            + intValue(row["promptTokens"])
        let cacheReadTokens = intValue(row["cacheReadTokens"])
            + intValue(row["totalCacheReadTokens"])
            + intValue(row["cacheReadInputTokens"])
        return CCHLeaderboardModelStat(
            id: "\(parentId)-model-\(model.lowercased())",
            model: model,
            requests: intValue(row["totalRequests"]),
            cost: doubleValue(row["totalCost"]),
            tokens: intValue(row["totalTokens"]),
            inputTokens: totalInputTokens,
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
            cacheReadTokens: cacheStat.inputTokens > 0 || cacheStat.cacheHitRateOverride != nil ? cacheStat.cacheReadTokens : stat.cacheReadTokens,
            cacheHitRateOverride: cacheStat.cacheHitRate ?? stat.cacheHitRate
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
        cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
        cacheHitRateOverride: rhs.cacheHitRate ?? lhs.cacheHitRate,
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
        cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
        cacheHitRateOverride: rhs.cacheHitRate ?? lhs.cacheHitRate
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
