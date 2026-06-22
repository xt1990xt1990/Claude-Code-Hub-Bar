import CryptoKit
import Foundation

struct UpstreamRateTarget {
    let providerId: Int
    let providerName: String
    let apiKey: String
}

struct UpstreamRateFetchOutcome {
    let snapshot: UpstreamRateSnapshot
    let credential: UpstreamRateCredential
}

enum UpstreamRateSiteDetector {
    static func detect(
        host: String,
        statusCode: Int,
        headers: [String: String],
        body: String = ""
    ) -> UpstreamRateSourceType {
        let loweredHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value.lowercased()) })
        if loweredHeaders["x-new-api-version"] != nil || loweredHeaders["x-oneapi-request-id"] != nil {
            return .newAPI
        }

        let combined = "\(host) \(body) \(loweredHeaders.values.joined(separator: " "))".lowercased()
        if combined.contains("new-api") || combined.contains("one-api") || combined.contains("/api/token/search") {
            return .newAPI
        }
        if combined.contains("sub2api") || combined.contains("/api/v1/auth/refresh") || combined.contains("balance_charge_rate") {
            return .sub2API
        }
        return .unknown
    }
}

actor UpstreamRateService {
    private let session: URLSession
    private let detectionSession: URLSession
    private let dateProvider: @Sendable () -> Date
    private let nonceProvider: @Sendable () -> String

    init(
        session: URLSession? = nil,
        detectionSession: URLSession? = nil,
        dateProvider: @escaping @Sendable () -> Date = { Date() },
        nonceProvider: @escaping @Sendable () -> String = { newAPIRandomNonce() }
    ) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = session ?? URLSession(configuration: config)
        self.dateProvider = dateProvider
        self.nonceProvider = nonceProvider

        let detectionConfig = URLSessionConfiguration.ephemeral
        detectionConfig.timeoutIntervalForRequest = 2
        detectionConfig.timeoutIntervalForResource = 3
        self.detectionSession = detectionSession ?? URLSession(configuration: detectionConfig)
    }

    func fetchSnapshot(credential: UpstreamRateCredential, targets: [UpstreamRateTarget]) async throws -> UpstreamRateFetchOutcome {
        switch credential.sourceType {
        case .sub2API:
            return try await fetchSub2Snapshot(credential: credential, targets: targets)
        case .newAPI:
            return try await fetchNewAPISnapshot(credential: credential, targets: targets)
        case .unknown:
            return UpstreamRateFetchOutcome(
                snapshot: UpstreamRateSnapshot(host: credential.host, sourceType: .unknown, status: .unsupported),
                credential: credential
            )
        }
    }

    func fetchBalance(credential: UpstreamRateCredential) async throws -> UpstreamRateFetchOutcome {
        switch credential.sourceType {
        case .sub2API:
            var nextCredential = credential
            if shouldRefreshSub2Token(nextCredential) {
                nextCredential = try await refreshSub2Token(nextCredential)
            }
            let balance = try await fetchSub2UserBalance(nextCredential)
            return UpstreamRateFetchOutcome(
                snapshot: UpstreamRateSnapshot(
                    host: credential.host,
                    sourceType: .sub2API,
                    status: .available,
                    balance: balance
                ),
                credential: nextCredential
            )
        case .newAPI:
            let accessToken = credential.newAPIAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            let cookieHeader = credential.newAPICookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !accessToken.isEmpty || !cookieHeader.isEmpty else {
                throw UpstreamRateServiceError.missingCredential("缺少 new-api 登录态")
            }
            let nextCredential = await hydrateNewAPIUserIdIfNeeded(credential)
            let balance = try await fetchNewAPIUserBalance(nextCredential)
            return UpstreamRateFetchOutcome(
                snapshot: UpstreamRateSnapshot(
                    host: credential.host,
                    sourceType: .newAPI,
                    status: .available,
                    balance: balance
                ),
                credential: nextCredential
            )
        case .unknown:
            return UpstreamRateFetchOutcome(
                snapshot: UpstreamRateSnapshot(host: credential.host, sourceType: .unknown, status: .unsupported),
                credential: credential
            )
        }
    }

    func detectSite(baseURL: String, host: String) async -> UpstreamRateSourceType {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let paths = ["/api/status", "/api/user/self/groups", "/api/v1/groups/available"]
        for path in paths {
            guard let url = URL(string: base + path) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await detectionSession.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                let body = String(decoding: data.prefix(2048), as: UTF8.self)
                let detected = UpstreamRateSiteDetector.detect(
                    host: host,
                    statusCode: http.statusCode,
                    headers: http.allHeaderFields.reduce(into: [String: String]()) { result, entry in
                        if let key = entry.key as? String {
                            result[key] = "\(entry.value)"
                        }
                    },
                    body: body
                )
                if detected != .unknown {
                    return detected
                }
            } catch {
                continue
            }
        }
        return .unknown
    }

    private func fetchSub2Snapshot(credential: UpstreamRateCredential, targets: [UpstreamRateTarget]) async throws -> UpstreamRateFetchOutcome {
        var nextCredential = credential
        if shouldRefreshSub2Token(nextCredential) {
            nextCredential = try await refreshSub2Token(nextCredential)
        }

        let balance = try? await fetchSub2UserBalance(nextCredential)
        let userGroupRates = (try? await listSub2UserGroupRates(nextCredential)) ?? [:]
        var entries: [UpstreamRateEntry] = []
        for target in targets {
            if let key = try await findSub2Key(credential: nextCredential, target: target),
               let group = try await resolveSub2Group(credential: nextCredential, key: key),
               let rate = group.effectiveRate(userGroupRates: userGroupRates) {
                entries.append(
                    UpstreamRateEntry(
                        providerId: target.providerId,
                        keyName: key.name.isEmpty ? target.providerName : key.name,
                        groupName: group.name.isEmpty ? "Group \(key.groupId ?? 0)" : group.name,
                        rate: rate
                    )
                )
            }
        }

        return UpstreamRateFetchOutcome(
            snapshot: UpstreamRateSnapshot(
                host: credential.host,
                sourceType: .sub2API,
                status: .available,
                entries: entries,
                balance: balance
            ),
            credential: nextCredential
        )
    }

    private func fetchNewAPISnapshot(credential: UpstreamRateCredential, targets: [UpstreamRateTarget]) async throws -> UpstreamRateFetchOutcome {
        let accessToken = credential.newAPIAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cookieHeader = credential.newAPICookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty || !cookieHeader.isEmpty else {
            throw UpstreamRateServiceError.missingCredential("缺少 new-api 登录态")
        }

        var nextCredential = credential
        nextCredential = await hydrateNewAPIUserIdIfNeeded(nextCredential)
        let balance = try? await fetchNewAPIUserBalance(nextCredential)
        let groups = (try? await listNewAPIGroups(nextCredential)) ?? [:]
        let variantGroups = groups.isEmpty ? (try? await listVariantNewAPIGroups(nextCredential)) ?? [:] : [:]
        var entries: [UpstreamRateEntry] = []

        for target in targets {
            if let token = try? await findNewAPIToken(credential: nextCredential, target: target) {
                let group = token.group
                if let rate = groups[group]?.ratio {
                    entries.append(
                        UpstreamRateEntry(
                            providerId: target.providerId,
                            keyName: token.name.isEmpty ? target.providerName : token.name,
                            groupName: group.isEmpty ? "默认" : group,
                            rate: rate
                        )
                    )
                }
            } else if let token = try await findVariantNewAPIToken(credential: nextCredential, target: target) {
                let group = token.preferredGroup
                if let rate = token.preferredRatio ?? variantGroups[group]?.ratio {
                    entries.append(
                        UpstreamRateEntry(
                            providerId: target.providerId,
                            keyName: token.name.isEmpty ? target.providerName : token.name,
                            groupName: group.isEmpty ? "默认" : group,
                            rate: rate
                        )
                    )
                }
            }
        }

        return UpstreamRateFetchOutcome(
            snapshot: UpstreamRateSnapshot(
                host: credential.host,
                sourceType: .newAPI,
                status: .available,
                entries: entries,
                balance: balance
            ),
            credential: nextCredential
        )
    }

    private func shouldRefreshSub2Token(_ credential: UpstreamRateCredential) -> Bool {
        if credential.sub2AuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        guard let expiresAt = credential.sub2TokenExpiresAt else { return true }
        return expiresAt.timeIntervalSinceNow <= 5 * 60
    }

    private func refreshSub2Token(_ credential: UpstreamRateCredential) async throws -> UpstreamRateCredential {
        let refreshToken = credential.sub2RefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !refreshToken.isEmpty else { throw UpstreamRateServiceError.missingCredential("缺少 Sub2API refresh token") }

        let body = try await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/v1/auth/refresh",
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: ["refresh_token": refreshToken],
            unwrap: .sub2
        )
        let dict = body as? [String: Any] ?? [:]
        let accessToken = serviceString(dict["access_token"])
        let nextRefreshToken = serviceString(dict["refresh_token"])
        guard !accessToken.isEmpty, !nextRefreshToken.isEmpty else {
            throw UpstreamRateServiceError.invalidResponse("Sub2API refresh 响应缺少 token")
        }

        let expiresIn = serviceDouble(dict["expires_in"], fallback: 0)
        var next = credential
        next.sub2AuthToken = accessToken
        next.sub2RefreshToken = nextRefreshToken
        next.sub2TokenExpiresAt = Date().addingTimeInterval(expiresIn)
        return next
    }

    private func fetchSub2UserBalance(_ credential: UpstreamRateCredential) async throws -> UpstreamBalanceSnapshot? {
        let value = try await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/v1/auth/me",
            headers: sub2Headers(credential),
            unwrap: .sub2
        )
        return parseSub2UserBalance(value as? [String: Any] ?? [:])
    }

    private func fetchNewAPIUserBalance(_ credential: UpstreamRateCredential) async throws -> UpstreamBalanceSnapshot? {
        let status = (try? await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/status",
            headers: ["Accept": "application/json"],
            unwrap: .newAPI
        )) as? [String: Any] ?? [:]

        let value = try await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/user/self",
            headers: newAPIHeaders(credential, signedPath: "/user/self"),
            unwrap: .newAPI
        )
        return parseNewAPIUserBalance(user: value as? [String: Any] ?? [:], status: status)
    }

    private func listSub2UserGroupRates(_ credential: UpstreamRateCredential) async throws -> [Int: Double] {
        let value = try await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/v1/groups/rates",
            headers: sub2Headers(credential),
            unwrap: .sub2
        )
        return parseSub2UserGroupRates(value)
    }

    private func findSub2Key(credential: UpstreamRateCredential, target: UpstreamRateTarget) async throws -> Sub2Key? {
        for page in 1...20 {
            let query = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "page_size", value: "100")
            ]
            let value = try await requestJSON(
                baseURL: credential.baseURL,
                path: "/api/v1/keys",
                queryItems: query,
                headers: sub2Headers(credential),
                unwrap: .sub2
            )
            let pageData = sub2Page(value)
            if let key = findSub2KeyByKey(rows: pageData.items, targetAPIKey: target.apiKey) {
                return key
            }
            if pageData.items.count < pageData.pageSize || page * pageData.pageSize >= pageData.total {
                return nil
            }
        }
        return nil
    }

    private func resolveSub2Group(credential: UpstreamRateCredential, key: Sub2Key) async throws -> Sub2Group? {
        if let group = key.group {
            return group
        }
        guard let groupId = key.groupId else { return nil }
        let value = try await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/v1/groups/available",
            headers: sub2Headers(credential),
            unwrap: .sub2
        )
        let rows = value as? [[String: Any]] ?? []
        return rows.map(Sub2Group.init).first { $0.id == groupId }
    }

    private func listNewAPIGroups(_ credential: UpstreamRateCredential) async throws -> [String: NewAPIGroup] {
        let value = try await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/user/self/groups",
            headers: newAPIHeaders(credential),
            unwrap: .newAPI
        )
        let dict = value as? [String: Any] ?? [:]
        var result: [String: NewAPIGroup] = [:]
        for (name, raw) in dict {
            result[name] = NewAPIGroup(name: name, raw: raw as? [String: Any] ?? [:])
        }
        return result
    }

    private func hydrateNewAPIUserIdIfNeeded(_ credential: UpstreamRateCredential) async -> UpstreamRateCredential {
        if !credential.newAPIUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return credential
        }
        var next = credential
        guard let value = try? await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/user/self",
            headers: newAPIHeaders(credential, signedPath: "/user/self"),
            unwrap: .newAPI
        ) else {
            return next
        }
        let dict = value as? [String: Any] ?? [:]
        let userId = serviceString(dict["id"] ?? dict["user_id"] ?? dict["userId"])
        if !userId.isEmpty {
            next.newAPIUserId = userId
        }
        return next
    }

    private func listVariantNewAPIGroups(_ credential: UpstreamRateCredential) async throws -> [String: NewAPIGroup] {
        var result: [String: NewAPIGroup] = [:]
        for type in ["subscription", "pay_as_you_go"] {
            let value = try await requestJSON(
                baseURL: credential.baseURL,
                path: "/api/groups/by-type",
                queryItems: [URLQueryItem(name: "type", value: type)],
                headers: newAPIHeaders(credential, signedPath: "/groups/by-type"),
                unwrap: .newAPI
            )
            for row in value as? [[String: Any]] ?? [] {
                let group = NewAPIGroup(row)
                if !group.name.isEmpty {
                    result[group.name] = group
                }
            }
        }
        return result
    }

    private func findNewAPIToken(credential: UpstreamRateCredential, target: UpstreamRateTarget) async throws -> NewAPIToken? {
        for tokenQuery in newAPITokenSearchQueries(target.apiKey) {
            if let token = try await findNewAPIToken(credential: credential, target: target, tokenQuery: tokenQuery) {
                return token
            }
        }
        return nil
    }

    private func findVariantNewAPIToken(credential: UpstreamRateCredential, target: UpstreamRateTarget) async throws -> VariantNewAPIToken? {
        for page in 1...20 {
            let query = [
                URLQueryItem(name: "p", value: "\(page - 1)"),
                URLQueryItem(name: "size", value: "100")
            ]
            let value = try await requestJSON(
                baseURL: credential.baseURL,
                path: "/api/token",
                queryItems: query,
                headers: newAPIHeaders(credential, signedPath: "/token"),
                unwrap: .newAPI
            )
            let pageData = variantNewAPIPage(value)
            for row in pageData.items {
                let token = VariantNewAPIToken(row)
                if tokenKeyMatches(token.key, target.apiKey) || tokenKeySuffixMatches(token.key, target.apiKey) {
                    return token
                }
            }
            if pageData.items.count < pageData.pageSize || page * pageData.pageSize >= pageData.total {
                return nil
            }
        }
        return nil
    }

    private func findNewAPIToken(credential: UpstreamRateCredential, target: UpstreamRateTarget, tokenQuery: String?) async throws -> NewAPIToken? {
        for page in 1...20 {
            var query = [
                URLQueryItem(name: "p", value: "\(page - 1)"),
                URLQueryItem(name: "size", value: "100")
            ]
            if let tokenQuery, !tokenQuery.isEmpty {
                query.append(URLQueryItem(name: "token", value: tokenQuery))
            }
            let value = try await requestJSON(
                baseURL: credential.baseURL,
                path: "/api/token/search",
                queryItems: query,
                headers: newAPIHeaders(credential),
                unwrap: .newAPI
            )
            let pageData = newAPIPage(value)
            for row in pageData.items {
                let token = NewAPIToken(row)
                if tokenKeyMatches(token.key, target.apiKey) {
                    return token
                }
                if token.id != nil, tokenMayMatchAfterReveal(token.key, target.apiKey) {
                    let revealed = try await revealNewAPIKey(credential: credential, token: token)
                    if tokenKeyMatches(revealed, target.apiKey) || tokenKeySuffixMatches(revealed, target.apiKey) {
                        var hydrated = token
                        hydrated.key = revealed
                        return hydrated
                    }
                }
            }
            if pageData.items.count < pageData.pageSize || page * pageData.pageSize >= pageData.total {
                return nil
            }
        }
        return nil
    }

    private func revealNewAPIKey(credential: UpstreamRateCredential, token: NewAPIToken) async throws -> String {
        guard let id = token.id else { return "" }
        let value = try await requestJSON(
            baseURL: credential.baseURL,
            path: "/api/token/\(id)/key",
            method: "POST",
            headers: newAPIHeaders(credential),
            body: [:],
            unwrap: .newAPI
        )
        if let key = value as? String {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return serviceString((value as? [String: Any])?["key"])
    }

    private func sub2Headers(_ credential: UpstreamRateCredential) -> [String: String] {
        ["Authorization": "Bearer \(credential.sub2AuthToken)", "Accept": "application/json"]
    }

    private func newAPIHeaders(_ credential: UpstreamRateCredential, signedPath: String? = nil) -> [String: String] {
        var headers = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        let token = credential.newAPIAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }
        let userId = credential.newAPIUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userId.isEmpty {
            headers["New-Api-User"] = userId
        }
        let cookieHeader = credential.newAPICookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cookieHeader.isEmpty {
            headers["Cookie"] = cookieHeader
        }
        if let signedPath {
            let signature = newAPISignature(path: signedPath, date: dateProvider(), nonce: nonceProvider())
            headers["X-Timestamp"] = signature.timestamp
            headers["X-Nonce"] = signature.nonce
            headers["X-Sign"] = signature.sign
        }
        return headers
    }

    private enum ResponseEnvelope {
        case none
        case sub2
        case newAPI
    }

    private func requestJSON(
        baseURL: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        headers: [String: String] = [:],
        body: [String: Any]? = nil,
        unwrap: ResponseEnvelope
    ) async throws -> Any {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: base + path) else { throw UpstreamRateServiceError.invalidURL }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw UpstreamRateServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UpstreamRateServiceError.invalidResponse("上游响应无效") }
        let value = data.isEmpty ? NSNull() : try JSONSerialization.jsonObject(with: data)
        guard (200...299).contains(http.statusCode) else {
            throw UpstreamRateServiceError.http(http.statusCode)
        }
        return try unwrapEnvelope(value, unwrap: unwrap)
    }

    private func unwrapEnvelope(_ value: Any, unwrap: ResponseEnvelope) throws -> Any {
        guard let dict = value as? [String: Any] else { return value }
        switch unwrap {
        case .none:
            return value
        case .sub2:
            if dict["code"] != nil, dict["data"] != nil {
                if serviceDouble(dict["code"]) != 0 {
                    throw UpstreamRateServiceError.invalidResponse(serviceString(dict["message"], fallback: "Sub2API 返回错误"))
                }
                return dict["data"] ?? NSNull()
            }
            return value
        case .newAPI:
            if let success = dict["success"] as? Bool {
                if !success {
                    throw UpstreamRateServiceError.invalidResponse(serviceString(dict["message"], fallback: "new-api 返回错误"))
                }
                return dict["data"] ?? NSNull()
            }
            return value
        }
    }
}

enum UpstreamRateServiceError: LocalizedError {
    case invalidURL
    case http(Int)
    case invalidResponse(String)
    case missingCredential(String)

    var isAuthenticationExpired: Bool {
        switch self {
        case .http(let code):
            return code == 401 || code == 403
        case .invalidResponse(let message):
            let normalized = message.lowercased()
            return normalized.contains("invalid refresh token")
                || normalized.contains("invalid token")
                || normalized.contains("token expired")
                || normalized.contains("unauthorized")
                || normalized.contains("forbidden")
                || normalized.contains("登录")
                || normalized.contains("授权")
        case .invalidURL, .missingCredential:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "上游地址无效"
        case .http(let code): return "上游 HTTP 错误 \(code)"
        case .invalidResponse(let message): return message
        case .missingCredential(let message): return message
        }
    }
}

struct Sub2Key {
    let id: Int?
    let key: String
    let name: String
    let groupId: Int?
    let group: Sub2Group?

    init(_ row: [String: Any]) {
        id = serviceInt(row["id"])
        key = serviceString(row["key"])
        name = serviceString(row["name"])
        groupId = serviceInt(row["group_id"] ?? row["groupId"])
        group = (row["group"] as? [String: Any]).map(Sub2Group.init)
    }
}

struct Sub2Group {
    let id: Int?
    let name: String
    let balanceChargeRate: Double?

    init(_ row: [String: Any]) {
        id = serviceInt(row["id"])
        name = serviceString(row["name"])
        balanceChargeRate = serviceOptionalDouble(row["balance_charge_rate"] ?? row["balanceChargeRate"] ?? row["rate_multiplier"] ?? row["rateMultiplier"])
    }

    func effectiveRate(userGroupRates: [Int: Double]) -> Double? {
        if let id, let userRate = userGroupRates[id] {
            return userRate
        }
        return balanceChargeRate
    }
}

private struct NewAPIToken {
    let id: Int?
    var key: String
    let name: String
    let group: String

    init(_ row: [String: Any]) {
        id = serviceInt(row["id"])
        key = serviceString(row["key"])
        name = serviceString(row["name"])
        group = serviceString(row["group"])
    }
}

private struct NewAPIGroup {
    let name: String
    let ratio: Double?

    init(name: String, raw: [String: Any]) {
        self.name = name
        ratio = serviceOptionalDouble(raw["ratio"])
    }

    init(_ row: [String: Any]) {
        name = serviceString(row["name"])
        ratio = serviceOptionalDouble(row["ratio"])
    }
}

private struct VariantNewAPIToken {
    let id: Int?
    let key: String
    let name: String
    let billingType: String
    let subscriptionGroupName: String
    let subscriptionGroupRatio: Double?
    let payAsYouGoGroupName: String
    let payAsYouGoGroupRatio: Double?

    init(_ row: [String: Any]) {
        id = serviceInt(row["id"])
        key = serviceString(row["key"])
        name = serviceString(row["name"])
        billingType = serviceString(row["billing_type"] ?? row["billingType"])
        let subscriptionGroup = row["subscription_group"] as? [String: Any] ?? row["subscriptionGroup"] as? [String: Any] ?? [:]
        let payAsYouGoGroup = row["pay_as_you_go_group"] as? [String: Any] ?? row["payAsYouGoGroup"] as? [String: Any] ?? [:]
        subscriptionGroupName = serviceString(subscriptionGroup["name"])
        subscriptionGroupRatio = serviceOptionalDouble(subscriptionGroup["ratio"])
        payAsYouGoGroupName = serviceString(payAsYouGoGroup["name"])
        payAsYouGoGroupRatio = serviceOptionalDouble(payAsYouGoGroup["ratio"])
    }

    var preferredGroup: String {
        !payAsYouGoGroupName.isEmpty ? payAsYouGoGroupName : subscriptionGroupName
    }

    var preferredRatio: Double? {
        payAsYouGoGroupRatio ?? subscriptionGroupRatio
    }
}

private func sub2Page(_ value: Any) -> (items: [[String: Any]], total: Int, pageSize: Int) {
    if let rows = value as? [[String: Any]] {
        return (rows, rows.count, max(rows.count, 1))
    }
    let dict = value as? [String: Any] ?? [:]
    let rows = dict["items"] as? [[String: Any]] ?? []
    return (rows, serviceInt(dict["total"]) ?? rows.count, serviceInt(dict["page_size"] ?? dict["pageSize"]) ?? max(rows.count, 1))
}

private func newAPIPage(_ value: Any) -> (items: [[String: Any]], total: Int, pageSize: Int) {
    if let rows = value as? [[String: Any]] {
        return (rows, rows.count, max(rows.count, 1))
    }
    let dict = value as? [String: Any] ?? [:]
    let nested = dict["data"] as? [String: Any] ?? [:]
    let rows = dict["items"] as? [[String: Any]] ?? nested["items"] as? [[String: Any]] ?? []
    return (rows, serviceInt(dict["total"] ?? nested["total"]) ?? rows.count, serviceInt(dict["size"] ?? nested["size"]) ?? max(rows.count, 1))
}

private func variantNewAPIPage(_ value: Any) -> (items: [[String: Any]], total: Int, pageSize: Int) {
    newAPIPage(value)
}

func parseSub2UserGroupRates(_ value: Any) -> [Int: Double] {
    if let dict = value as? [String: Any] {
        var result: [Int: Double] = [:]
        for (key, rawValue) in dict {
            if let id = Int(key), let rate = serviceOptionalDouble(rawValue) {
                result[id] = rate
            } else if
                let row = rawValue as? [String: Any],
                let id = serviceInt(row["group_id"] ?? row["groupId"] ?? row["id"]),
                let rate = serviceOptionalDouble(row["rate_multiplier"] ?? row["rateMultiplier"] ?? row["balance_charge_rate"] ?? row["balanceChargeRate"]) {
                result[id] = rate
            }
        }
        return result
    }

    if let rows = value as? [[String: Any]] {
        var result: [Int: Double] = [:]
        for row in rows {
            guard
                let id = serviceInt(row["group_id"] ?? row["groupId"] ?? row["id"]),
                let rate = serviceOptionalDouble(row["rate_multiplier"] ?? row["rateMultiplier"] ?? row["balance_charge_rate"] ?? row["balanceChargeRate"])
            else { continue }
            result[id] = rate
        }
        return result
    }

    return [:]
}

private func normalizeNewAPIKey(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"^sk-"#, with: "", options: .regularExpression)
}

private func newAPIKeySuffix(_ value: String) -> String {
    let normalized = normalizeNewAPIKey(value).replacingOccurrences(of: "*", with: "")
    guard normalized.count >= 4 else { return "" }
    return String(normalized.suffix(4))
}

private func newAPITokenSearchQueries(_ apiKey: String) -> [String?] {
    let normalized = normalizeNewAPIKey(apiKey)
    let suffix = newAPIKeySuffix(apiKey)
    if normalized.count <= 4, !suffix.isEmpty {
        return ["%\(suffix)", nil]
    }
    return [normalized, suffix.isEmpty ? nil : "%\(suffix)", nil]
}

func normalizeSub2Key(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: #"^sk-"#, with: "", options: [.regularExpression, .caseInsensitive])
        .lowercased()
}

func sub2KeySuffix(_ value: String) -> String {
    let normalized = normalizeSub2Key(value).replacingOccurrences(of: "*", with: "")
    guard normalized.count >= 4 else { return "" }
    return String(normalized.suffix(4))
}

func sub2KeyMatches(_ lhs: String, _ rhs: String) -> Bool {
    let left = normalizeSub2Key(lhs)
    let right = normalizeSub2Key(rhs)
    if left.isEmpty || right.isEmpty {
        return false
    }
    if left == right {
        return true
    }
    let leftSuffix = sub2KeySuffix(lhs)
    let rightSuffix = sub2KeySuffix(rhs)
    return !leftSuffix.isEmpty && leftSuffix == rightSuffix
}

func findSub2KeyByKey(rows: [[String: Any]], targetAPIKey: String) -> Sub2Key? {
    let keys = rows.map(Sub2Key.init)
    if let exact = keys.first(where: { normalizeSub2Key($0.key) == normalizeSub2Key(targetAPIKey) }) {
        return exact
    }
    return keys.first { sub2KeyMatches($0.key, targetAPIKey) }
}

func parseSub2UserBalance(_ user: [String: Any]) -> UpstreamBalanceSnapshot? {
    guard let balance = serviceOptionalDouble(user["balance"]) else { return nil }
    return UpstreamBalanceSnapshot(
        displayAmount: balance,
        unit: "USD",
        totalRechargedDisplayAmount: serviceOptionalDouble(user["total_recharged"] ?? user["totalRecharged"])
    )
}

func parseNewAPIUserBalance(user: [String: Any], status: [String: Any]) -> UpstreamBalanceSnapshot? {
    let quotaPerUnit = max(serviceOptionalDouble(status["quota_per_unit"] ?? status["quotaPerUnit"]) ?? 500_000, 1)
    if let quota = serviceOptionalDouble(user["quota"]) {
        let usedQuota = serviceOptionalDouble(user["used_quota"] ?? user["usedQuota"])
        return UpstreamBalanceSnapshot(
            displayAmount: quota / quotaPerUnit,
            unit: "USD",
            rawAmount: quota,
            usedDisplayAmount: usedQuota.map { $0 / quotaPerUnit }
        )
    }
    if let balance = serviceOptionalDouble(user["balance"]) {
        return UpstreamBalanceSnapshot(displayAmount: balance, unit: "USD")
    }
    return nil
}

private func tokenKeyMatches(_ lhs: String, _ rhs: String) -> Bool {
    let left = normalizeNewAPIKey(lhs)
    let right = normalizeNewAPIKey(rhs)
    return !left.isEmpty && left == right
}

private func tokenKeySuffixMatches(_ lhs: String, _ rhs: String) -> Bool {
    let leftSuffix = newAPIKeySuffix(lhs)
    let rightSuffix = newAPIKeySuffix(rhs)
    return !leftSuffix.isEmpty && leftSuffix == rightSuffix
}

private func maskedTokenMayMatch(_ tokenKey: String, _ targetKey: String) -> Bool {
    let token = normalizeNewAPIKey(tokenKey)
    let target = normalizeNewAPIKey(targetKey)
    guard token.contains("*"), token.count >= 8, target.count >= 8 else { return false }
    return target.hasPrefix(String(token.prefix(4))) && target.hasSuffix(String(token.suffix(4)))
}

private func tokenMayMatchAfterReveal(_ tokenKey: String, _ targetKey: String) -> Bool {
    maskedTokenMayMatch(tokenKey, targetKey) || tokenKeySuffixMatches(tokenKey, targetKey)
}

private func serviceString(_ value: Any?, fallback: String = "") -> String {
    switch value {
    case let string as String: return string
    case let number as NSNumber: return number.stringValue
    default: return fallback
    }
}

private func serviceInt(_ value: Any?) -> Int? {
    switch value {
    case let int as Int: return int
    case let number as NSNumber: return number.intValue
    case let string as String: return Int(string)
    default: return nil
    }
}

private func serviceOptionalDouble(_ value: Any?) -> Double? {
    switch value {
    case let double as Double: return double
    case let int as Int: return Double(int)
    case let number as NSNumber: return number.doubleValue
    case let string as String:
        if string == "自动" { return nil }
        return Double(string)
    default: return nil
    }
}

private func serviceDouble(_ value: Any?, fallback: Double = 0) -> Double {
    serviceOptionalDouble(value) ?? fallback
}

private struct NewAPISignature {
    let timestamp: String
    let nonce: String
    let sign: String
}

private func newAPISignature(path: String, date: Date, nonce: String) -> NewAPISignature {
    let timestamp = String(Int(date.timeIntervalSince1970))
    let payload = "\(timestamp)\(nonce)\(path)nekoneko"
    let digest = SHA256.hash(data: Data(payload.utf8))
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    return NewAPISignature(timestamp: timestamp, nonce: nonce, sign: String(hex.prefix(16)))
}

private func newAPIRandomNonce() -> String {
    let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    return String((0..<8).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
}
