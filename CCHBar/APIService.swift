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

struct CCHLeaderboardEntry: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let requests: Int
    let cost: Double
    let tokens: Int
    let inputTokens: Int
    let cacheReadTokens: Int
    let successRate: Double?

    var cacheHitRate: Double? {
        guard inputTokens > 0 else { return nil }
        return Double(cacheReadTokens) / Double(inputTokens)
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
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let costUsd: Double
    let durationMs: Int?
    let ttfbMs: Int?
    let tokensPerSecond: Double?
    let errorMessage: String
    let providerChain: [CCHProviderChainItem]
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
        let data = try await postAction(config: config, module: "overview", action: "getOverviewData")
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
        let data = try await postAction(config: config, module: "active-sessions", action: "getActiveSessions")
        guard let rows = data as? [[String: Any]] else { throw APIError.parseError }
        return rows.map { row in
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
    }

    func fetchLeaderboard(config: CCHConfig, period: String, scope: String) async throws -> [CCHLeaderboardEntry] {
        let base = try normalizedBaseURL(config)
        guard var components = URLComponents(string: base + "/api/leaderboard") else {
            throw APIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "includeModelStats", value: "1")
        ]
        guard let url = components.url else { throw APIError.invalidURL }
        let value = try await requestJSON(config: config, url: url, method: "GET", body: nil)
        guard let rows = value as? [[String: Any]] else { throw APIError.parseError }

        return rows.map { row in
            let title: String
            let subtitle: String
            switch scope {
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

            return CCHLeaderboardEntry(
                title: title,
                subtitle: subtitle,
                requests: intValue(row["totalRequests"]),
                cost: doubleValue(row["totalCost"]),
                tokens: intValue(row["totalTokens"]),
                inputTokens: intValue(row["totalInputTokens"])
                    + intValue(row["inputTokens"])
                    + intValue(row["promptTokens"]),
                cacheReadTokens: intValue(row["totalCacheReadTokens"])
                    + intValue(row["cacheReadTokens"])
                    + intValue(row["cacheReadInputTokens"]),
                successRate: row["successRate"] == nil ? nil : doubleValue(row["successRate"])
            )
        }
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
        var body: [String: Any] = [
            "page": page,
            "pageSize": pageSize
        ]
        if let startDate {
            body["startDate"] = ISO8601DateFormatter().string(from: startDate)
            body["endDate"] = ISO8601DateFormatter().string(from: Date())
        }
        if !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["model"] = model.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let code = Int(statusCode.trimmingCharacters(in: .whitespacesAndNewlines)) {
            body["statusCode"] = code
        }
        if !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["sessionId"] = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let data = try await postAction(config: config, module: "usage-logs", action: "getUsageLogs", body: body)
        guard let dict = data as? [String: Any] else { throw APIError.parseError }
        let rows = dict["logs"] as? [[String: Any]] ?? []
        let summary = dict["summary"] as? [String: Any] ?? [:]
        return CCHLogsPage(
            logs: rows.map(parseLog),
            total: intValue(dict["total"]),
            summary: CCHLogSummary(
                totalRequests: intValue(summary["totalRequests"]),
                totalCost: doubleValue(summary["totalCost"]),
                totalTokens: intValue(summary["totalTokens"]),
                inputTokens: intValue(summary["totalInputTokens"]),
                outputTokens: intValue(summary["totalOutputTokens"]),
                cacheCreationTokens: intValue(summary["totalCacheCreationTokens"])
                    + intValue(summary["totalCacheCreation1hTokens"])
                    + intValue(summary["totalCacheCreation5mTokens"]),
                cacheReadTokens: intValue(summary["totalCacheReadTokens"])
            )
        )
    }

    func fetchProviders(config: CCHConfig) async throws -> [CCHProvider] {
        let providersData = try await postAction(config: config, module: "providers", action: "getProviders")
        let healthData = try? await postAction(config: config, module: "providers", action: "getProvidersHealthStatus")
        guard let rows = providersData as? [[String: Any]] else { throw APIError.parseError }
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
        _ = try await postAction(
            config: config,
            module: "providers",
            action: "editProvider",
            body: ["providerId": providerId, "is_enabled": enabled]
        )
    }

    func resetProviderCircuit(config: CCHConfig, providerId: Int) async throws {
        _ = try await postAction(
            config: config,
            module: "providers",
            action: "resetProviderCircuit",
            body: ["providerId": providerId]
        )
    }

    func probeFirstEndpoint(config: CCHConfig, provider: CCHProvider) async throws -> CCHProbeResult {
        guard let vendorId = provider.vendorId else {
            throw APIError.actionError("这个 Provider 没有可测速的 Vendor")
        }
        let endpointsData = try await postAction(
            config: config,
            module: "providers",
            action: "getProviderEndpoints",
            body: ["vendorId": vendorId, "providerType": provider.providerType]
        )
        guard let rows = endpointsData as? [[String: Any]] else { throw APIError.parseError }
        guard let endpoint = rows.first(where: { boolValue($0["isEnabled"]) }) ?? rows.first else {
            throw APIError.actionError("没有可测速的端点")
        }

        let endpointId = intValue(endpoint["id"])
        let data = try await postAction(
            config: config,
            module: "providers",
            action: "probeProviderEndpoint",
            body: ["endpointId": endpointId, "timeoutMs": 12000]
        )
        guard
            let dict = data as? [String: Any],
            let result = dict["result"] as? [String: Any]
        else {
            throw APIError.parseError
        }

        return CCHProbeResult(
            ok: boolValue(result["ok"]),
            method: stringValue(result["method"]),
            statusCode: optionalInt(result["statusCode"]),
            latencyMs: optionalInt(result["latencyMs"]),
            errorMessage: stringValue(result["errorMessage"])
        )
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
            inputTokens: intValue(row["inputTokens"]),
            outputTokens: intValue(row["outputTokens"]),
            totalTokens: intValue(row["totalTokens"]),
            cacheCreationTokens: intValue(row["cacheCreationInputTokens"]),
            cacheReadTokens: intValue(row["cacheReadInputTokens"]),
            costUsd: doubleValue(row["costUsd"]),
            durationMs: optionalInt(row["durationMs"]),
            ttfbMs: optionalInt(row["ttfbMs"]),
            tokensPerSecond: optionalDouble(row["tokensPerSecond"]) ?? optionalDouble(row["tokensPerSecondTokens"]) ?? optionalDouble(row["outputTokensPerSecond"]),
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
