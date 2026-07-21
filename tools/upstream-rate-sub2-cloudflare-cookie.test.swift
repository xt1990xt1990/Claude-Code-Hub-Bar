import Darwin
import Foundation

@main
private struct UpstreamRateSub2CloudflareCookieTests {
    @MainActor
    static func main() async throws {
        try testSub2BrowserImportStoresCookieHeader()
        try testSub2BrowserImportAcceptsCookieOnlyRefreshToken()
        try await testSub2CookieOnlyLoginUsesValidator()
        try await testSub2LoginValidationFallsBackToBodyTokens()
        try await testSub2MalformedRefreshResponseIsRejected()
        try testSub2HeadersIncludeBrowserCookie()
        try testNewAPIHeadersIncludeBrowserCookieAndUserAgent()
        try testNewAPICookieOnlyHeadersUseBrowserUserAgentFallback()
        try await testNekoProfileLoginValidation()
        try testChromeAuthUsesSharedProfile()
    }

    @MainActor
    private static func testSub2BrowserImportStoresCookieHeader() throws {
        let importer = UpstreamChromeAuthImporter(
            validateNewAPILogin: { _ in true }
        )
        let credential = UpstreamRateCredential.empty(host: "sub.kedaya.xyz", sourceType: .sub2API)
        let next = try importer.mergeBrowserState(
            (
                storage: [
                    "auth_token": "access-token",
                    "refresh_token": "refresh-token"
                ],
                cookieHeader: "cf_clearance=ok; session=browser",
                userAgent: "Mozilla/5.0 Chrome/126.0"
            ),
            into: credential
        )

        try expect(next.sub2CookieHeader == "cf_clearance=ok; session=browser", "Sub2API browser cookie should be stored")
        try expect(next.userAgent == "Mozilla/5.0 Chrome/126.0", "browser User-Agent should be stored")
    }

    @MainActor
    private static func testSub2BrowserImportAcceptsCookieOnlyRefreshToken() throws {
        let importer = UpstreamChromeAuthImporter(
            validateNewAPILogin: { _ in true }
        )
        var credential = UpstreamRateCredential.empty(host: "ageteam.online", sourceType: .sub2API)
        credential.sub2RefreshToken = "stale-keychain-token"
        let next = try importer.mergeBrowserState(
            (
                storage: [:],
                cookieHeader: "sub2api_refresh_token=browser",
                userAgent: "Mozilla/5.0 Chrome/149.0"
            ),
            into: credential
        )

        try expect(next.sub2CookieHeader == "sub2api_refresh_token=browser", "Sub2API cookie-only refresh token should be stored")
        try expect(next.sub2RefreshToken == "browser", "Sub2API refresh token field should be hydrated from refresh cookie")
        try expect(next.userAgent == "Mozilla/5.0 Chrome/149.0", "browser User-Agent should be stored for cookie-only Sub2API login")
        try importer.requireFreshBrowserCredential(
            (
                storage: [:],
                cookieHeader: "sub2api_refresh_token=browser",
                userAgent: "Mozilla/5.0 Chrome/149.0"
            ),
            sourceType: .sub2API
        )
    }

    @MainActor
    private static func testSub2CookieOnlyLoginUsesValidator() async throws {
        let importer = UpstreamChromeAuthImporter(
            validateNewAPILogin: { _ in true },
            validateSub2APILogin: { _ in nil }
        )
        var credential = UpstreamRateCredential.empty(host: "ageteam.online", sourceType: .sub2API)
        credential.sub2CookieHeader = "sub2api_refresh_token=browser"

        let validated = await importer.isValidatedLogin(credential)
        try expect(!validated, "Sub2API cookie-only login should be checked by the upstream validator")
    }

    private static func testSub2MalformedRefreshResponseIsRejected() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MalformedSub2RefreshProtocol.self]
        let session = URLSession(configuration: config)
        var credential = UpstreamRateCredential.empty(host: "malformed.example.test", sourceType: .sub2API)
        credential.baseURL = "https://malformed.example.test"
        credential.sub2CookieHeader = "sub2api_refresh_token=browser"
        credential.sub2RefreshToken = "browser"

        let validated = await UpstreamChromeAuthImporter.validateSub2APILogin(
            credential,
            session: session
        )
        if validated != nil {
            fputs("FAIL: malformed 2xx refresh response must not validate browser login\n", stderr)
            exit(1)
        }
    }

    private static func testSub2LoginValidationFallsBackToBodyTokens() async throws {
        BodyRequiredSub2ValidationProtocol.refreshBodies = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BodyRequiredSub2ValidationProtocol.self]
        var credential = UpstreamRateCredential.empty(host: "ageteam.online", sourceType: .sub2API)
        credential.sub2CookieHeader = "cf_clearance=ok; sub2api_refresh_token=cookie-refresh"
        credential.sub2RefreshToken = "field-refresh"

        let validated = await UpstreamChromeAuthImporter.validateSub2APILogin(
            credential,
            session: URLSession(configuration: config)
        )

        try expect(validated != nil, "Sub2API browser validation should fall back to body refresh tokens")
        try expect(
            BodyRequiredSub2ValidationProtocol.refreshBodies.count == 3,
            "browser validation should try every distinct Sub2API refresh credential"
        )
        try expect(
            BodyRequiredSub2ValidationProtocol.refreshBodies[0] == #"{}"#,
            "browser validation should preserve the Cookie-only first attempt"
        )
        try expect(
            BodyRequiredSub2ValidationProtocol.refreshBodies[1].contains(#""refresh_token":"cookie-refresh""#),
            "browser validation should retry with the Cookie token in the body"
        )
        try expect(
            BodyRequiredSub2ValidationProtocol.refreshBodies[2].contains(#""refresh_token":"field-refresh""#),
            "browser validation should retry with a distinct stored token"
        )
        try expect(validated?.sub2AuthToken == "body-access", "body fallback should hydrate the access token")
        try expect(validated?.sub2RefreshToken == "rotated-body", "body fallback should persist the rotated token")
        try expect(
            validated?.sub2CookieHeader.contains("sub2api_refresh_token=rotated-body") == true,
            "body fallback should replace the stale refresh Cookie"
        )
    }

    private static func testSub2HeadersIncludeBrowserCookie() throws {
        var credential = UpstreamRateCredential.empty(host: "sub.kedaya.xyz", sourceType: .sub2API)
        credential.sub2AuthToken = "access-token"
        credential.sub2CookieHeader = "cf_clearance=ok; session=browser"
        credential.userAgent = "Mozilla/5.0 Chrome/126.0"

        let headers = upstreamRateSub2Headers(credential)
        try expect(headers["Authorization"] == "Bearer access-token", "Sub2API auth header should be preserved")
        try expect(headers["Cookie"] == "cf_clearance=ok; session=browser", "Sub2API cookie header should be sent")
        try expect(headers["User-Agent"] == "Mozilla/5.0 Chrome/126.0", "browser User-Agent should be sent")
        try expect(headers["Accept"] == "application/json", "Sub2API accept header should be preserved")
    }

    private static func testNewAPIHeadersIncludeBrowserCookieAndUserAgent() throws {
        var credential = UpstreamRateCredential.empty(host: "new.example.com", sourceType: .newAPI)
        credential.newAPIAccessToken = "access-token"
        credential.newAPIUserId = "42"
        credential.newAPICookieHeader = "cf_clearance=ok; session=browser"
        credential.userAgent = "Mozilla/5.0 Chrome/126.0"

        let headers = upstreamRateNewAPIHeaders(credential)
        try expect(headers["Authorization"] == "Bearer access-token", "new-api auth header should be preserved")
        try expect(headers["New-Api-User"] == "42", "new-api user id header should be preserved")
        try expect(headers["Cookie"] == "cf_clearance=ok; session=browser", "new-api cookie header should be sent")
        try expect(headers["User-Agent"] == "Mozilla/5.0 Chrome/126.0", "new-api browser User-Agent should be sent")
        try expect(headers["Accept"] == "application/json", "new-api accept header should be preserved")
        try expect(headers["Content-Type"] == "application/json", "new-api content type should be preserved")
    }

    private static func testNewAPICookieOnlyHeadersUseBrowserUserAgentFallback() throws {
        var credential = UpstreamRateCredential.empty(host: "nekocode.ai", sourceType: .newAPI)
        credential.newAPICookieHeader = "session=browser"

        let headers = upstreamRateNewAPIHeaders(credential)
        try expect(headers["Cookie"] == "session=browser", "new-api cookie header should be sent")
        try expect(
            headers["User-Agent"]?.contains("Chrome/") == true,
            "cookie-session new-api requests should use a browser User-Agent fallback when none was captured"
        )
    }

    private static func testNekoProfileLoginValidation() async throws {
        NekoProfileLoginValidationProtocol.requests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NekoProfileLoginValidationProtocol.self]
        let session = URLSession(configuration: config)
        var credential = UpstreamRateCredential.empty(host: "nekocode.ai", sourceType: .newAPI)
        credential.newAPICookieHeader = "session=browser"
        credential.userAgent = "Mozilla/5.0 Chrome/149.0"

        let validated = await UpstreamChromeAuthImporter.validateNewAPILogin(
            credential,
            session: session
        )

        try expect(validated, "Neko cookie login should validate through /api/user/profile")
        let request = NekoProfileLoginValidationProtocol.requests.first
        try expect(request?.url?.path == "/api/user/profile", "Neko login validation should use the current profile endpoint first")
        try expect(request?.value(forHTTPHeaderField: "Cookie") == "session=browser", "Neko login validation should send the browser Cookie")
        try expect(request?.value(forHTTPHeaderField: "User-Agent") == "Mozilla/5.0 Chrome/149.0", "Neko login validation should send the browser User-Agent")
        try expect(request?.value(forHTTPHeaderField: "X-Timestamp")?.isEmpty == false, "Neko profile validation should include a timestamp")
        try expect(request?.value(forHTTPHeaderField: "X-Nonce")?.count == 8, "Neko profile validation should include an eight-character nonce")
        try expect(request?.value(forHTTPHeaderField: "X-Sign")?.count == 16, "Neko profile validation should include a 16-character signature")
    }

    @MainActor
    private static func testChromeAuthUsesSharedProfile() throws {
        let importer = UpstreamChromeAuthImporter(
            validateNewAPILogin: { _ in true }
        )
        let kedaya = UpstreamRateCredential.empty(host: "sub.kedaya.xyz", sourceType: .sub2API)
        let love = UpstreamRateCredential.empty(host: "gy.fwhzfyy.asia", sourceType: .sub2API)

        let kedayaPath = importer.chromeProfilePath(for: kedaya)
        let lovePath = importer.chromeProfilePath(for: love)

        try expect(kedayaPath == lovePath, "Chrome auth should reuse one shared app profile across upstream hosts")
        try expect(kedayaPath.lastPathComponent == "shared", "shared Chrome auth profile should be named shared")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw NSError(domain: "UpstreamRateSub2CloudflareCookieTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}

private final class MalformedSub2RefreshProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<html>challenge</html>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class NekoProfileLoginValidationProtocol: URLProtocol {
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        let isProfileRequest = request.url?.path == "/api/user/profile"
        let status = isProfileRequest ? 200 : 404
        let body = isProfileRequest
            ? #"{"success":true,"data":{"id":3911}}"#
            : #"{"success":false,"message":"not found"}"#
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class BodyRequiredSub2ValidationProtocol: URLProtocol {
    static var refreshBodies: [String] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let requestBody = String(decoding: requestBodyData(request), as: UTF8.self)
        Self.refreshBodies.append(requestBody)
        let body: String
        if requestBody.contains(#""refresh_token":"field-refresh""#) {
            body = #"{"code":0,"data":{"access_token":"body-access","refresh_token":"rotated-body","expires_in":3600}}"#
        } else if requestBody == #"{}"# {
            body = #"{"code":"REFRESH_TOKEN_REQUIRED","message":"Refresh token required","data":null}"#
        } else {
            body = #"{"code":"INVALID_REFRESH_TOKEN","message":"Invalid refresh token","data":null}"#
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func requestBodyData(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
