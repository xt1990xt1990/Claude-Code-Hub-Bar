import AppKit
import Foundation

struct UpstreamChromeAuthResult {
    let credential: UpstreamRateCredential
    let importedFieldCount: Int
}

enum UpstreamChromeAuthError: LocalizedError {
    case chromeNotFound
    case noInspectablePage(String)
    case missingLocalStorageCredential(UpstreamRateSourceType)
    case invalidDevToolsResponse

    var errorDescription: String? {
        switch self {
        case .chromeNotFound:
            return "未找到 Google Chrome"
        case .noInspectablePage(let host):
            return "没有找到 \(host) 的 Chrome 登录页"
        case .missingLocalStorageCredential(let type):
            return "没有从 Chrome 读取到 \(type.title) 登录态"
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
    private var chromeProcess: Process?

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
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

        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        var lastError: Error?
        while Date() < deadline {
            do {
                let state = try await readBrowserState(for: credential)
                let next = try mergeBrowserState(state, into: credential)
                let importedCount = importedFieldCount(before: credential, after: next)
                closeChrome()
                step = .imported
                message = importedCount > 0 ? "获取成功" : "登录态已存在"
                return UpstreamChromeAuthResult(credential: next, importedFieldCount: importedCount)
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
        let next = try mergeBrowserState(state, into: credential)
        let importedCount = importedFieldCount(before: credential, after: next)
        message = importedCount > 0 ? "已读取 \(importedCount) 个字段" : "没有新字段"
        return UpstreamChromeAuthResult(credential: next, importedFieldCount: importedCount)
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

    private func readBrowserState(for credential: UpstreamRateCredential) async throws -> (storage: [String: String], cookieHeader: String) {
        let page = try await findPage(for: credential)
        guard let webSocketDebuggerURL = page.webSocketDebuggerURL else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }
        let task = session.webSocketTask(with: webSocketDebuggerURL)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        let storage = try await evaluateLocalStorage(using: task, id: 1)
        let cookieHeader = try await readCookieHeader(for: page.url, using: task, id: 2)
        print("UpstreamChromeAuthImporter state host=\(credential.host) storageKeys=\(storage.count) cookieHeaderLen=\(cookieHeader.count)")
        return (storage, cookieHeader)
    }

    private func mergeBrowserState(
        _ state: (storage: [String: String], cookieHeader: String),
        into credential: UpstreamRateCredential
    ) throws -> UpstreamRateCredential {
        var next = try UpstreamChromeLocalStorageParser.merge(storage: state.storage, into: credential)
        if credential.sourceType == .newAPI, !state.cookieHeader.isEmpty {
            next.newAPICookieHeader = state.cookieHeader
        }
        if
            credential.sourceType == .newAPI,
            next.newAPIAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            next.newAPICookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UpstreamChromeAuthError.missingLocalStorageCredential(.newAPI)
        }
        return next
    }

    private func evaluateLocalStorage(using task: URLSessionWebSocketTask, id: Int) async throws -> [String: String] {
        let expression = """
        (() => {
          const out = {};
          for (let i = 0; i < localStorage.length; i += 1) {
            const key = localStorage.key(i);
            out[key] = localStorage.getItem(key);
          }
          return out;
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
            let value = resultObject["value"] as? [String: Any]
        else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }
        return value.compactMapValues { $0 as? String }
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

    private func findPage(for credential: UpstreamRateCredential) async throws -> ChromePage {
        let host = normalizedUpstreamHost(credential.baseURL) ?? credential.host
        guard let listURL = URL(string: "http://127.0.0.1:\(port)/json") else {
            throw UpstreamChromeAuthError.invalidDevToolsResponse
        }

        for _ in 0..<20 {
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

    func chromeProfilePath(for credential: UpstreamRateCredential) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let host = normalizedUpstreamHost(credential.baseURL) ?? credential.host
        let profileName = sanitizedProfileName(host)
        return appSupport
            .appendingPathComponent("CCHBar/UpstreamChromeProfiles", isDirectory: true)
            .appendingPathComponent(profileName, isDirectory: true)
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
