import AppKit
import CryptoKit
import Foundation

struct UpstreamChromeAuthResult {
    let credential: UpstreamRateCredential
    let importedFieldCount: Int
}

enum UpstreamChromeAuthError: LocalizedError {
    case chromeNotFound
    case noInspectablePage(String)
    case missingLocalStorageCredential(UpstreamRateSourceType)
    case loginValidationFailed(UpstreamRateSourceType)
    case invalidDevToolsResponse

    var errorDescription: String? {
        switch self {
        case .chromeNotFound:
            return "未找到 Google Chrome"
        case .noInspectablePage(let host):
            return "没有找到 \(host) 的 Chrome 登录页"
        case .missingLocalStorageCredential(let type):
            return "没有从 Chrome 读取到 \(type.title) 登录态"
        case .loginValidationFailed(let type):
            return "\(type.title) 登录态校验失败，请确认网页里已经登录完成"
        case .invalidDevToolsResponse:
            return "Chrome DevTools 响应无效"
        }
    }
}

enum UpstreamChromeAuthStep: Equatable {
    case idle
    case opening
    case waiting
    case imported
    case failed(String)

    var title: String {
        switch self {
        case .idle: return "获取登录态"
        case .opening: return "正在打开 Chrome..."
        case .waiting: return "等待登录完成..."
        case .imported: return "获取成功"
        case .failed(let message): return message
        }
    }
}

enum UpstreamChromeLocalStorageParser {
    static func merge(
        storage: [String: String],
        into credential: UpstreamRateCredential,
        now: Date = Date()
    ) throws -> UpstreamRateCredential {
        let flattened = flattenLocalStorage(storage)
        var next = credential

        switch credential.sourceType {
        case .newAPI:
            let accessToken = firstString(
                in: flattened,
                exactKeys: ["auth_token", "authToken", "access_token", "accessToken", "token", "user.token", "state.user.token"],
                suffixes: ["auth_token", "authToken", "access_token", "accessToken", "user.token"]
            )
            let userId = firstString(
                in: flattened,
                exactKeys: ["uid", "user_id", "userId", "id", "user.id", "state.user.id"],
                suffixes: ["uid", "user_id", "userId", "user.id"]
            )
            guard !accessToken.isEmpty || !userId.isEmpty else {
                throw UpstreamChromeAuthError.missingLocalStorageCredential(.newAPI)
            }
            if !accessToken.isEmpty {
                next.newAPIAccessToken = accessToken
            }
            if !userId.isEmpty {
                next.newAPIUserId = userId
            }
        case .sub2API:
            let authToken = firstString(
                in: flattened,
                exactKeys: ["auth_token", "authToken", "access_token", "accessToken"],
                suffixes: ["auth_token", "authToken", "access_token", "accessToken"]
            )
            let refreshToken = firstString(
                in: flattened,
                exactKeys: ["refresh_token", "refreshToken"],
                suffixes: ["refresh_token", "refreshToken"]
            )
            guard !authToken.isEmpty || !refreshToken.isEmpty else {
                throw UpstreamChromeAuthError.missingLocalStorageCredential(.sub2API)
            }
            if !authToken.isEmpty {
                next.sub2AuthToken = authToken
            }
            if !refreshToken.isEmpty {
                next.sub2RefreshToken = refreshToken
            }
            if let expiresAt = sub2ExpiresAt(from: flattened, now: now) {
                next.sub2TokenExpiresAt = expiresAt
            }
        case .unknown:
            throw UpstreamChromeAuthError.missingLocalStorageCredential(.unknown)
        }

        return next
    }

    private static func flattenLocalStorage(_ storage: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in storage {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            result[key] = trimmed
            if let json = parseJSONString(trimmed) {
                flattenJSON(json, prefix: key, into: &result)
                if key.localizedCaseInsensitiveContains("auth") || key.localizedCaseInsensitiveContains("user") {
                    flattenJSON(json, prefix: "", into: &result)
                }
            }
        }
        return result
    }

    private static func parseJSONString(_ value: String) -> Any? {
        guard let data = value.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func flattenJSON(_ value: Any, prefix: String, into result: inout [String: String]) {
        if let dict = value as? [String: Any] {
            for (key, child) in dict {
                let nextPrefix = prefix.isEmpty ? key : "\(prefix).\(key)"
                flattenJSON(child, prefix: nextPrefix, into: &result)
            }
            return
        }
        if let array = value as? [Any] {
            for (index, child) in array.enumerated() {
                let nextPrefix = prefix.isEmpty ? "\(index)" : "\(prefix).\(index)"
                flattenJSON(child, prefix: nextPrefix, into: &result)
            }
            return
        }
        let string = storageString(value)
        if !prefix.isEmpty, !string.isEmpty {
            result[prefix] = string
        }
    }

    private static func storageString(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        default:
            return ""
        }
    }

    private static func firstString(in values: [String: String], exactKeys: [String], suffixes: [String]) -> String {
        for key in exactKeys {
            if let value = values[key], !value.isEmpty {
                return value
            }
        }
        let loweredSuffixes = suffixes.map { $0.lowercased() }
        let match = values
            .filter { _, value in !value.isEmpty }
            .sorted { $0.key.count < $1.key.count }
            .first { key, _ in
                let lowercased = key.lowercased()
                return loweredSuffixes.contains { suffix in
                    lowercased == suffix || lowercased.hasSuffix(".\(suffix)")
                }
            }
        return match?.value ?? ""
    }

    private static func sub2ExpiresAt(from values: [String: String], now: Date) -> Date? {
        if let expiresAt = numericValue(for: ["token_expires_at", "tokenExpiresAt", "expires_at", "expiresAt"], in: values) {
            if expiresAt > 10_000_000_000 {
                return Date(timeIntervalSince1970: expiresAt / 1_000)
            }
            return Date(timeIntervalSince1970: expiresAt)
        }
        if let expiresIn = numericValue(for: ["expires_in", "expiresIn"], in: values), expiresIn > 0 {
            return now.addingTimeInterval(expiresIn)
        }
        return nil
    }

    private static func numericValue(for keys: [String], in values: [String: String]) -> Double? {
        for key in keys {
            if let value = values[key], let number = Double(value) {
                return number
            }
        }
        let loweredKeys = keys.map { $0.lowercased() }
        let match = values.first { key, value in
            Double(value) != nil && loweredKeys.contains { lowered in
                let lowercased = key.lowercased()
                return lowercased == lowered || lowercased.hasSuffix(".\(lowered)")
            }
        }
        if let value = match?.value {
            return Double(value)
        }
        return nil
    }
}

@MainActor
final class UpstreamChromeAuthImporter: ObservableObject {
    @Published private(set) var isImporting = false
    @Published private(set) var message: String?
    @Published private(set) var step: UpstreamChromeAuthStep = .idle

    private let port = 49_521
    private let session: URLSession
    private let validateNewAPILogin: (UpstreamRateCredential) async -> Bool
    private let validateSub2APILogin: (UpstreamRateCredential) async -> UpstreamRateCredential?
    private var chromeProcess: Process?

    init(
        validateNewAPILogin: @escaping (UpstreamRateCredential) async -> Bool = UpstreamChromeAuthImporter.defaultValidateNewAPILogin,
        validateSub2APILogin: @escaping (UpstreamRateCredential) async -> UpstreamRateCredential? = UpstreamChromeAuthImporter.defaultValidateSub2APILogin
    ) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
        self.validateNewAPILogin = validateNewAPILogin
        self.validateSub2APILogin = validateSub2APILogin
    }

    func openChrome(for credential: UpstreamRateCredential) throws {
        let baseURL = normalizedBaseURL(credential.baseURL)
        guard let chromeURL = findChromeApplicationURL() else {
            throw UpstreamChromeAuthError.chromeNotFound
        }

        closeChrome()
        terminateStaleChromeProcesses()

        let profilePath = chromeProfilePath(for: credential)
        try FileManager.default.createDirectory(at: profilePath, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = chromeURL.appendingPathComponent("Contents/MacOS/Google Chrome")
        process.arguments = [
            "--remote-debugging-address=127.0.0.1",
            "--remote-debugging-port=\(port)",
            "--remote-allow-origins=*",
            "--user-data-dir=\(profilePath.path)",
            "--no-first-run",
            "--no-default-browser-check",
            baseURL
        ]
        try process.run()
        chromeProcess = process
        message = "Chrome 已打开，登录完成后点读取"
    }

    func captureLogin(for credential: UpstreamRateCredential, timeoutSeconds: Int = 120) async throws -> UpstreamChromeAuthResult {
        isImporting = true
        step = .opening
        defer { isImporting = false }

        try openChrome(for: credential)
        step = .waiting
        await clearStaleBrowserCredential(for: credential)

        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        var lastError: Error?
        while Date() < deadline {
            do {
                let state = try await readBrowserState(for: credential)
                try requireFreshBrowserCredential(state, sourceType: credential.sourceType)
                let next = try mergeBrowserState(state, into: credential)
                guard let validated = await validatedLoginCredential(next) else {
                    throw UpstreamChromeAuthError.loginValidationFailed(credential.sourceType)
                }
                let importedCount = importedFieldCount(before: credential, after: validated)
                closeChrome()
                step = .imported
                message = importedCount > 0 ? "获取成功" : "登录态已存在"
                return UpstreamChromeAuthResult(credential: validated, importedFieldCount: importedCount)
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        let message = lastError?.localizedDescription ?? "登录超时"
        step = .failed(message)
        throw lastError ?? UpstreamChromeAuthError.noInspectablePage(credential.host)
    }

    func importCredential(_ credential: UpstreamRateCredential) async throws -> UpstreamChromeAuthResult {
        isImporting = true
        defer { isImporting = false }

        let state = try await readBrowserState(for: credential)
        try requireFreshBrowserCredential(state, sourceType: credential.sourceType)
        let next = try mergeBrowserState(state, into: credential)
        guard let validated = await validatedLoginCredential(next) else {
            throw UpstreamChromeAuthError.loginValidationFailed(credential.sourceType)
        }
        let importedCount = importedFieldCount(before: credential, after: validated)
        message = importedCount > 0 ? "已读取 \(importedCount) 个字段" : "没有新字段"
        return UpstreamChromeAuthResult(credential: validated, importedFieldCount: importedCount)
    }

    func closeChrome() {
        if let chromeProcess, chromeProcess.isRunning {
            chromeProcess.terminate()
        }
        chromeProcess = nil
    }

    private func readLocalStorage(for credential: UpstreamRateCredential) async throws -> [String: String] {
        try await readBrowserState(for: credential).storage
    }

    func requireFreshBrowserCredential(
        _ state: (storage: [String: String], cookieHeader: String, userAgent: String),
        sourceType: UpstreamRateSourceType
    ) throws {
        let fresh = try mergeBrowserState(
            state,
            into: UpstreamRateCredential.empty(host: "validation.local", sourceType: sourceType)
        )
        switch sourceType {
        case .newAPI:
            if fresh.newAPIAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               fresh.newAPICookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw UpstreamChromeAuthError.missingLocalStorageCredential(.newAPI)
            }
        case .sub2API:
            if fresh.sub2AuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               fresh.sub2RefreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !upstreamRateSub2CookieContainsRefreshToken(fresh.sub2CookieHeader) {
                throw UpstreamChromeAuthError.missingLocalStorageCredential(.sub2API)
            }
        case .unknown:
            throw UpstreamChromeAuthError.missingLocalStorageCredential(.unknown)
        }
    }

    private func readBrowserState(for credential: UpstreamRateCredential) async throws -> (storage: [String: String], cookieHeader: String, userAgent: String) {
        let page: ChromePage
        do {
            page = try await findPage(for: credential)
        } catch UpstreamChromeAuthError.noInspectablePage {
            return try await readBrowserCookieState(for: credential)
        }
        guard let webSocketDebuggerURL = page.webSocketDebuggerURL else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }
        let task = session.webSocketTask(with: webSocketDebuggerURL)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        let storage = try await evaluateBrowserStorage(using: task, id: 1)
        let cookieHeader = try await readCookieHeader(for: page.url, using: task, id: 2)
        let userAgent = try await readUserAgent(using: task, id: 3)
        print("UpstreamChromeAuthImporter state host=\(credential.host) storageKeys=\(storage.count) cookieHeaderLen=\(cookieHeader.count) userAgentLen=\(userAgent.count)")
        return (storage, cookieHeader, userAgent)
    }

    private func readBrowserCookieState(for credential: UpstreamRateCredential) async throws -> (storage: [String: String], cookieHeader: String, userAgent: String) {
        let host = normalizedUpstreamHost(credential.baseURL) ?? credential.host
        guard let versionURL = URL(string: "http://127.0.0.1:\(port)/json/version") else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }
        let browser = try await fetchBrowserVersion(from: versionURL)
        guard let webSocketDebuggerURL = browser.webSocketDebuggerURL else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }

        let task = session.webSocketTask(with: webSocketDebuggerURL)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        let cookieHeader = try await readBrowserCookieHeader(host: host, using: task, id: 10_001)
        let userAgent = browser.userAgent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (try? await readBrowserVersionUserAgent(using: task, id: 10_002)) ?? ""
            : browser.userAgent
        print("UpstreamChromeAuthImporter browser-state host=\(credential.host) storageKeys=0 cookieHeaderLen=\(cookieHeader.count) userAgentLen=\(userAgent.count)")
        return ([:], cookieHeader, userAgent)
    }

    func mergeBrowserState(
        _ state: (storage: [String: String], cookieHeader: String, userAgent: String),
        into credential: UpstreamRateCredential
    ) throws -> UpstreamRateCredential {
        var next: UpstreamRateCredential
        do {
            next = try UpstreamChromeLocalStorageParser.merge(storage: state.storage, into: credential)
        } catch UpstreamChromeAuthError.missingLocalStorageCredential(.newAPI)
            where credential.sourceType == .newAPI && !state.cookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next = credential
        } catch UpstreamChromeAuthError.missingLocalStorageCredential(.sub2API)
            where credential.sourceType == .sub2API && upstreamRateSub2CookieContainsRefreshToken(state.cookieHeader) {
            next = credential
        }
        if credential.sourceType == .sub2API, !state.cookieHeader.isEmpty {
            next.sub2CookieHeader = state.cookieHeader
            let cookieRefreshToken = upstreamRateSub2RefreshTokenCookieValue(state.cookieHeader)
            if !cookieRefreshToken.isEmpty {
                next.sub2RefreshToken = cookieRefreshToken
            }
        }
        if credential.sourceType == .newAPI, !state.cookieHeader.isEmpty {
            next.newAPICookieHeader = state.cookieHeader
        }
        if !state.userAgent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next.userAgent = state.userAgent
        }
        if
            credential.sourceType == .newAPI,
            next.newAPIAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            next.newAPICookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UpstreamChromeAuthError.missingLocalStorageCredential(.newAPI)
        }
        return next
    }

    func isValidatedLogin(_ credential: UpstreamRateCredential) async -> Bool {
        await validatedLoginCredential(credential) != nil
    }

    private func validatedLoginCredential(_ credential: UpstreamRateCredential) async -> UpstreamRateCredential? {
        switch credential.sourceType {
        case .newAPI:
            return await validateNewAPILogin(credential) ? credential : nil
        case .sub2API:
            return await validateSub2APILogin(credential)
        case .unknown:
            return nil
        }
    }

    private func evaluateBrowserStorage(using task: URLSessionWebSocketTask, id: Int) async throws -> [String: String] {
        let expression = """
        (() => {
          const copy = (storage) => {
            const out = {};
            for (let i = 0; i < storage.length; i += 1) {
              const key = storage.key(i);
              out[key] = storage.getItem(key);
            }
            return out;
          }
          return {
            localStorage: copy(localStorage),
            sessionStorage: copy(sessionStorage)
          };
        })()
        """
        let payload: [String: Any] = [
            "id": id,
            "method": "Runtime.evaluate",
            "params": [
                "expression": expression,
                "returnByValue": true,
                "awaitPromise": true
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(decoding: data, as: UTF8.self)
        try await send(text, using: task)
        let responseData = try await receiveResponseData(id: id, using: task)
        guard
            let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let result = object["result"] as? [String: Any],
            let resultObject = result["result"] as? [String: Any],
            let value = resultObject["value"] as? [String: Any],
            let localStorage = value["localStorage"] as? [String: Any],
            let sessionStorage = value["sessionStorage"] as? [String: Any]
        else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }
        return browserStorage(localStorage: localStorage, sessionStorage: sessionStorage)
    }

    private func readUserAgent(using task: URLSessionWebSocketTask, id: Int) async throws -> String {
        let payload: [String: Any] = [
            "id": id,
            "method": "Runtime.evaluate",
            "params": [
                "expression": "navigator.userAgent",
                "returnByValue": true
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await send(String(decoding: data, as: UTF8.self), using: task)
        let responseData = try await receiveResponseData(id: id, using: task)
        guard
            let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let result = object["result"] as? [String: Any],
            let resultObject = result["result"] as? [String: Any],
            let value = resultObject["value"] as? String
        else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }
        return value
    }

    func browserStorage(localStorage: [String: Any], sessionStorage: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in localStorage {
            guard let string = value as? String else { continue }
            result[key] = string
            result["localStorage.\(key)"] = string
        }
        for (key, value) in sessionStorage {
            guard let string = value as? String else { continue }
            if result[key] == nil {
                result[key] = string
            }
            result["sessionStorage.\(key)"] = string
        }
        return result
    }

    private func readCookieHeader(for pageURL: String, using task: URLSessionWebSocketTask, id: Int) async throws -> String {
        let host = normalizedUpstreamHost(pageURL)
        let payload: [String: Any] = [
            "id": id,
            "method": "Network.getCookies",
            "params": [
                "urls": [pageURL]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(decoding: data, as: UTF8.self)
        try await send(text, using: task)
        let responseData = try await receiveResponseData(id: id, using: task)
        let networkCookies = parseCookieRows(from: responseData)
        let networkHeader = cookieHeader(from: networkCookies, host: host)
        if !networkHeader.isEmpty {
            return networkHeader
        }

        let fallbackPayload: [String: Any] = [
            "id": id + 10_000,
            "method": "Storage.getCookies",
            "params": [:]
        ]
        let fallbackData = try JSONSerialization.data(withJSONObject: fallbackPayload)
        try await send(String(decoding: fallbackData, as: UTF8.self), using: task)
        let fallbackResponseData = try await receiveResponseData(id: id + 10_000, using: task)
        return cookieHeader(from: parseCookieRows(from: fallbackResponseData), host: host)
    }

    private func readBrowserCookieHeader(host: String, using task: URLSessionWebSocketTask, id: Int) async throws -> String {
        let payload: [String: Any] = [
            "id": id,
            "method": "Storage.getCookies",
            "params": [:]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await send(String(decoding: data, as: UTF8.self), using: task)
        let responseData = try await receiveResponseData(id: id, using: task)
        return cookieHeader(from: parseCookieRows(from: responseData), host: host)
    }

    private func readBrowserVersionUserAgent(using task: URLSessionWebSocketTask, id: Int) async throws -> String {
        let payload: [String: Any] = [
            "id": id,
            "method": "Browser.getVersion",
            "params": [:]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await send(String(decoding: data, as: UTF8.self), using: task)
        let responseData = try await receiveResponseData(id: id, using: task)
        guard
            let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let result = object["result"] as? [String: Any],
            let userAgent = result["userAgent"] as? String
        else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }
        return userAgent
    }

    private func parseCookieRows(from responseData: Data) -> [[String: Any]] {
        guard
            let object = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let result = object["result"] as? [String: Any],
            let cookies = result["cookies"] as? [[String: Any]]
        else { return [] }
        return cookies
    }

    func cookieHeader(from cookies: [[String: Any]], host: String?) -> String {
        cookies
            .filter { cookie in
                guard let host else { return true }
                let domain = (cookie["domain"] as? String ?? "").trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
                return domain.isEmpty || domain == host || host.hasSuffix(".\(domain)")
            }
            .compactMap { cookie in
                guard
                    let name = cookie["name"] as? String,
                    let value = cookie["value"] as? String,
                    !name.isEmpty
                else { return nil }
                return "\(name)=\(value)"
            }
            .joined(separator: "; ")
    }

    static func defaultValidateNewAPILogin(_ credential: UpstreamRateCredential) async -> Bool {
        await validateNewAPILogin(credential, session: .shared)
    }

    static func validateNewAPILogin(
        _ credential: UpstreamRateCredential,
        session: URLSession
    ) async -> Bool {
        let accessToken = credential.newAPIAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cookieHeader = credential.newAPICookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty || !cookieHeader.isEmpty else {
            print("UpstreamChromeAuthImporter newAPI validation host=\(credential.host) result=missing-auth")
            return false
        }

        let base = credential.baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let userId = credential.newAPIUserId.trimmingCharacters(in: .whitespacesAndNewlines)

        for probe in NewAPILoginValidationProbe.defaultProbes {
            guard let url = URL(string: base + probe.apiPath) else {
                print("UpstreamChromeAuthImporter newAPI validation host=\(credential.host) result=invalid-url path=\(probe.apiPath)")
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if !accessToken.isEmpty {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            if !userId.isEmpty {
                request.setValue(userId, forHTTPHeaderField: "New-Api-User")
            }
            if !cookieHeader.isEmpty {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            let userAgent = upstreamRateUserAgentHeader(credential.userAgent, cookieHeader: cookieHeader)
            if !userAgent.isEmpty {
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            }
            if let signedPath = probe.signedPath {
                let signature = newAPIBrowserAuthSignature(path: signedPath)
                request.setValue(signature.timestamp, forHTTPHeaderField: "X-Timestamp")
                request.setValue(signature.nonce, forHTTPHeaderField: "X-Nonce")
                request.setValue(signature.sign, forHTTPHeaderField: "X-Sign")
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    print("UpstreamChromeAuthImporter newAPI validation host=\(credential.host) path=\(probe.apiPath) status=\(status) success=false userIdSet=\(!userId.isEmpty) tokenLen=\(accessToken.count) cookieLen=\(cookieHeader.count)")
                    continue
                }
                guard
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let success = object["success"] as? Bool
                else {
                    print("UpstreamChromeAuthImporter newAPI validation host=\(credential.host) path=\(probe.apiPath) status=2xx success=unknown userIdSet=\(!userId.isEmpty) tokenLen=\(accessToken.count) cookieLen=\(cookieHeader.count)")
                    return true
                }
                let message = (object["message"] as? String ?? "").prefix(80)
                print("UpstreamChromeAuthImporter newAPI validation host=\(credential.host) path=\(probe.apiPath) status=2xx success=\(success) message=\(message) userIdSet=\(!userId.isEmpty) tokenLen=\(accessToken.count) cookieLen=\(cookieHeader.count)")
                if success {
                    return true
                }
            } catch {
                print("UpstreamChromeAuthImporter newAPI validation host=\(credential.host) path=\(probe.apiPath) error=\(error.localizedDescription) userIdSet=\(!userId.isEmpty) tokenLen=\(accessToken.count) cookieLen=\(cookieHeader.count)")
            }
        }
        return false
    }

    static func defaultValidateSub2APILogin(_ credential: UpstreamRateCredential) async -> UpstreamRateCredential? {
        await validateSub2APILogin(credential, session: .shared)
    }

    static func validateSub2APILogin(
        _ credential: UpstreamRateCredential,
        session: URLSession
    ) async -> UpstreamRateCredential? {
        var next = credential
        let shouldRefresh = next.sub2AuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (next.sub2TokenExpiresAt?.timeIntervalSinceNow ?? 0) <= 5 * 60
        if shouldRefresh {
            let refreshToken = next.sub2RefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasCookieRefreshToken = upstreamRateSub2CookieContainsRefreshToken(next.sub2CookieHeader)
            guard !refreshToken.isEmpty || hasCookieRefreshToken else {
                print("UpstreamChromeAuthImporter Sub2API validation host=\(credential.host) result=missing-auth")
                return nil
            }
            guard let url = URL(string: upstreamRateBrowserAuthBaseURL(credential.baseURL) + "/api/v1/auth/refresh") else {
                print("UpstreamChromeAuthImporter Sub2API validation host=\(credential.host) result=invalid-url")
                return nil
            }
            var baseRequest = URLRequest(url: url)
            baseRequest.httpMethod = "POST"
            baseRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            baseRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            baseRequest.setValue(
                upstreamRateUserAgentHeader(credential.userAgent, cookieHeader: credential.sub2CookieHeader),
                forHTTPHeaderField: "User-Agent"
            )
            if !credential.sub2CookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                baseRequest.setValue(credential.sub2CookieHeader, forHTTPHeaderField: "Cookie")
            }
            let requestBodies = upstreamRateSub2RefreshRequestBodies(credential)
            for (index, body) in requestBodies.enumerated() {
                var request = baseRequest
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (data, response) = try await session.data(for: request)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        print("UpstreamChromeAuthImporter Sub2API validation host=\(credential.host) path=/api/v1/auth/refresh attempt=\(index + 1)/\(requestBodies.count) status=\(status) success=false refreshTokenSet=\(!refreshToken.isEmpty) cookieLen=\(credential.sub2CookieHeader.count)")
                        continue
                    }
                    guard
                        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let code = upstreamRateBrowserAuthDouble(object["code"])
                    else {
                        print("UpstreamChromeAuthImporter Sub2API validation host=\(credential.host) path=/api/v1/auth/refresh attempt=\(index + 1)/\(requestBodies.count) status=2xx success=unknown refreshTokenSet=\(!refreshToken.isEmpty) cookieLen=\(credential.sub2CookieHeader.count)")
                        continue
                    }
                    let nested = object["data"] as? [String: Any] ?? [:]
                    let token = upstreamRateBrowserAuthString(nested["access_token"])
                    let success = code == 0 && !token.isEmpty
                    let message = upstreamRateBrowserAuthString(object["message"]).prefix(80)
                    print("UpstreamChromeAuthImporter Sub2API validation host=\(credential.host) path=/api/v1/auth/refresh attempt=\(index + 1)/\(requestBodies.count) status=2xx success=\(success) message=\(message) refreshTokenSet=\(!refreshToken.isEmpty) cookieLen=\(credential.sub2CookieHeader.count)")
                    guard success else { continue }

                    next.sub2AuthToken = token
                    let nextRefreshToken = upstreamRateBrowserAuthString(nested["refresh_token"])
                    let refreshState = upstreamRateUpdatedSub2RefreshState(
                        credential: credential,
                        response: http,
                        responseBodyToken: nextRefreshToken
                    )
                    next.sub2CookieHeader = refreshState.cookieHeader
                    next.sub2RefreshToken = refreshState.refreshToken
                    if let expiresIn = upstreamRateBrowserAuthDouble(nested["expires_in"]), expiresIn > 0 {
                        next.sub2TokenExpiresAt = Date().addingTimeInterval(expiresIn)
                    }
                    return next
                } catch {
                    print("UpstreamChromeAuthImporter Sub2API validation host=\(credential.host) path=/api/v1/auth/refresh attempt=\(index + 1)/\(requestBodies.count) error=\(error.localizedDescription) refreshTokenSet=\(!refreshToken.isEmpty) cookieLen=\(credential.sub2CookieHeader.count)")
                }
            }
            return nil
        }
        return credential
    }

    private func send(_ text: String, using task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(.string(text)) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func receiveResponseData(id: Int, using task: URLSessionWebSocketTask) async throws -> Data {
        for _ in 0..<10 {
            let message = try await task.receive()
            let data: Data
            switch message {
            case .data(let payload):
                data = payload
            case .string(let string):
                data = Data(string.utf8)
            @unknown default:
                throw UpstreamChromeAuthError.invalidDevToolsResponse
            }
            if
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let responseId = object["id"] as? Int,
                responseId == id {
                return data
            }
        }
        throw UpstreamChromeAuthError.invalidDevToolsResponse
    }

    private func clearStaleBrowserCredential(for credential: UpstreamRateCredential) async {
        guard credential.sourceType == .sub2API else { return }
        do {
            let page = try await findPage(for: credential, attempts: 10)
            guard let webSocketDebuggerURL = page.webSocketDebuggerURL else { return }
            let task = session.webSocketTask(with: webSocketDebuggerURL)
            task.resume()
            defer { task.cancel(with: .normalClosure, reason: nil) }

            try await deleteBrowserCookie(
                name: "sub2api_refresh_token",
                pageURL: page.url,
                using: task,
                id: 20_001
            )
            try? await reloadPage(using: task, id: 20_002)
            print("UpstreamChromeAuthImporter cleared stale Sub2API browser cookie host=\(credential.host)")
        } catch {
            print("UpstreamChromeAuthImporter clear stale Sub2API cookie skipped host=\(credential.host) error=\(error.localizedDescription)")
        }
    }

    private func deleteBrowserCookie(name: String, pageURL: String, using task: URLSessionWebSocketTask, id: Int) async throws {
        let payload: [String: Any] = [
            "id": id,
            "method": "Network.deleteCookies",
            "params": [
                "name": name,
                "url": pageURL
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await send(String(decoding: data, as: UTF8.self), using: task)
        _ = try await receiveResponseData(id: id, using: task)
    }

    private func reloadPage(using task: URLSessionWebSocketTask, id: Int) async throws {
        let payload: [String: Any] = [
            "id": id,
            "method": "Page.reload",
            "params": [
                "ignoreCache": true
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await send(String(decoding: data, as: UTF8.self), using: task)
        _ = try await receiveResponseData(id: id, using: task)
    }

    private func findPage(for credential: UpstreamRateCredential, attempts: Int = 20) async throws -> ChromePage {
        let host = normalizedUpstreamHost(credential.baseURL) ?? credential.host
        guard let listURL = URL(string: "http://127.0.0.1:\(port)/json") else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }

        for _ in 0..<attempts {
            if let pages = try? await fetchPages(from: listURL),
               let page = pages.first(where: { page in
                   page.type == "page" && (normalizedUpstreamHost(page.url) == host || page.url.contains(host))
               }) {
                return page
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        throw UpstreamChromeAuthError.noInspectablePage(host)
    }

    private func fetchPages(from url: URL) async throws -> [ChromePage] {
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([ChromePage].self, from: data)
    }

    private func fetchBrowserVersion(from url: URL) async throws -> ChromeBrowserVersion {
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ChromeBrowserVersion.self, from: data)
    }

    private func normalizedBaseURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://") {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return "https://\(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
    }

    private func findChromeApplicationURL() -> URL? {
        let candidates = [
            "/Applications/Google Chrome.app",
            "\(NSHomeDirectory())/Applications/Google Chrome.app"
        ]
        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func chromeProfilePath(for _: UpstreamRateCredential) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("CCHBar/UpstreamChromeProfiles", isDirectory: true)
            .appendingPathComponent("shared", isDirectory: true)
    }

    func sanitizedProfileName(_ value: String) -> String {
        let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let scalars = lowercased.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let name = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-_"))
        return name.isEmpty ? "default" : name
    }

    private func terminateStaleChromeProcesses() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = [
            "-f",
            "Google Chrome.*CCHBar/UpstreamChromeProfiles|Google Chrome.*CCHBar/UpstreamChromeProfile|Google Chrome.*remote-debugging-port=49521"
        ]
        try? process.run()
        process.waitUntilExit()
    }

    private func importedFieldCount(before: UpstreamRateCredential, after: UpstreamRateCredential) -> Int {
        var count = 0
        if before.sub2AuthToken != after.sub2AuthToken, !after.sub2AuthToken.isEmpty { count += 1 }
        if before.sub2RefreshToken != after.sub2RefreshToken, !after.sub2RefreshToken.isEmpty { count += 1 }
        if before.sub2TokenExpiresAt != after.sub2TokenExpiresAt, after.sub2TokenExpiresAt != nil { count += 1 }
        if before.sub2CookieHeader != after.sub2CookieHeader, !after.sub2CookieHeader.isEmpty { count += 1 }
        if before.userAgent != after.userAgent, !after.userAgent.isEmpty { count += 1 }
        if before.newAPIUserId != after.newAPIUserId, !after.newAPIUserId.isEmpty { count += 1 }
        if before.newAPIAccessToken != after.newAPIAccessToken, !after.newAPIAccessToken.isEmpty { count += 1 }
        if before.newAPICookieHeader != after.newAPICookieHeader, !after.newAPICookieHeader.isEmpty { count += 1 }
        return count
    }
}

private struct ChromePage: Decodable {
    let type: String
    let url: String
    let webSocketDebuggerURL: URL?

    private enum CodingKeys: String, CodingKey {
        case type
        case url
        case webSocketDebuggerURL = "webSocketDebuggerUrl"
    }
}

private struct ChromeBrowserVersion: Decodable {
    let userAgent: String
    let webSocketDebuggerURL: URL?

    private enum CodingKeys: String, CodingKey {
        case userAgent = "User-Agent"
        case webSocketDebuggerURL = "webSocketDebuggerUrl"
    }
}

private struct NewAPILoginValidationProbe {
    let apiPath: String
    let signedPath: String?

    static let defaultProbes = [
        NewAPILoginValidationProbe(apiPath: "/api/user/profile", signedPath: "/user/profile"),
        NewAPILoginValidationProbe(apiPath: "/api/user/self/groups", signedPath: nil),
        NewAPILoginValidationProbe(apiPath: "/api/user/self", signedPath: "/user/self")
    ]
}

private struct NewAPIBrowserAuthSignature {
    let timestamp: String
    let nonce: String
    let sign: String
}

private func newAPIBrowserAuthSignature(path: String, date: Date = Date(), nonce: String = newAPIBrowserAuthRandomNonce()) -> NewAPIBrowserAuthSignature {
    let timestamp = String(Int(date.timeIntervalSince1970))
    let payload = "\(timestamp)\(nonce)\(path)nekoneko"
    let digest = SHA256.hash(data: Data(payload.utf8))
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    return NewAPIBrowserAuthSignature(timestamp: timestamp, nonce: nonce, sign: String(hex.prefix(16)))
}

private func newAPIBrowserAuthRandomNonce() -> String {
    let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    return String((0..<8).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
}

private func upstreamRateBrowserAuthBaseURL(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if trimmed.contains("://") {
        return trimmed
    }
    return "https://\(trimmed)"
}

private func upstreamRateBrowserAuthString(_ value: Any?) -> String {
    switch value {
    case let string as String:
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    case let number as NSNumber:
        return number.stringValue
    default:
        return ""
    }
}

private func upstreamRateBrowserAuthDouble(_ value: Any?) -> Double? {
    switch value {
    case let double as Double:
        return double
    case let int as Int:
        return Double(int)
    case let number as NSNumber:
        return number.doubleValue
    case let string as String:
        return Double(string)
    default:
        return nil
    }
}
