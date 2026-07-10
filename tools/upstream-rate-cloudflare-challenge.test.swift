import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func expectTrue(_ condition: Bool, _ message: String) {
    guard condition else { fail(message) }
}

private func expectFalse(_ condition: Bool, _ message: String) {
    guard !condition else { fail(message) }
}

@main
private struct UpstreamRateCloudflareChallengeTests {
    static func main() async {
        await testCloudflareChallengeClassification()
        await testHTTPStatusIsCheckedBeforeJSONParsing()
        await testSub2CookieOnlyRefreshUsesBrowserCookie()
        await testSub2BodyTokenRefreshKeepsRequestBody()
        await testCrossOriginRefreshCookieIsRejected()
        await testNewAPIBalanceFallsBackToUserProfile()
        testNekocodeHostIsDetectedAsNewAPI()
    }

    private static func testCloudflareChallengeClassification() async {
        let challengeError = UpstreamRateServiceError.http(
            403,
            headers: ["cf-mitigated": "challenge"]
        )
        expectTrue(
            challengeError.isCloudflareChallenge,
            "403 with cf-mitigated challenge should be classified as Cloudflare challenge"
        )
        expectFalse(
            challengeError.isAuthenticationExpired,
            "Cloudflare challenge should not be treated as expired login state"
        )

        let plainForbidden = UpstreamRateServiceError.http(403, headers: [:])
        expectFalse(
            plainForbidden.isCloudflareChallenge,
            "plain 403 should not be classified as Cloudflare challenge"
        )
        expectTrue(
            plainForbidden.isAuthenticationExpired,
            "plain 403 should keep existing expired-login behavior"
        )

        let cloudflareForbidden = UpstreamRateServiceError.http(
            403,
            headers: ["Server": "cloudflare"]
        )
        expectTrue(
            cloudflareForbidden.isCloudflareChallenge,
            "403 from Cloudflare should be classified as Cloudflare challenge"
        )
        expectFalse(
            cloudflareForbidden.isAuthenticationExpired,
            "403 from Cloudflare should not be treated as expired login state"
        )

        let cloudflareRateLimit = UpstreamRateServiceError.http(
            429,
            headers: ["cf-ray": "test-ray"]
        )
        expectTrue(
            cloudflareRateLimit.isCloudflareChallenge,
            "429 with cf-* headers should be classified as Cloudflare challenge"
        )
    }

    private static func testHTTPStatusIsCheckedBeforeJSONParsing() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CloudflareHTMLChallengeProtocol.self]
        let session = URLSession(configuration: config)
        let service = UpstreamRateService(session: session)
        var credential = UpstreamRateCredential.empty(host: "cf.example.test", sourceType: .sub2API)
        credential.sub2AuthToken = "access-token"
        credential.sub2TokenExpiresAt = Date().addingTimeInterval(3600)

        do {
            _ = try await service.fetchBalance(credential: credential)
            fail("expected Cloudflare HTML response to throw HTTP error")
        } catch let error as UpstreamRateServiceError {
            switch error {
            case .http(let code, let headers):
                expectTrue(code == 403, "Cloudflare HTML response should preserve HTTP status")
                expectTrue(headers["Server"] == "cloudflare", "Cloudflare HTML response should preserve headers")
                expectTrue(error.isCloudflareChallenge, "Cloudflare HTML response should be classified from headers")
            case .invalidURL, .invalidResponse, .missingCredential:
                fail("expected HTTP error, got \(error)")
            }
        } catch {
            fail("expected UpstreamRateServiceError.http, got \(error)")
        }
    }

    private static func testSub2CookieOnlyRefreshUsesBrowserCookie() async {
        Sub2CookieOnlyRefreshProtocol.requests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Sub2CookieOnlyRefreshProtocol.self]
        let session = URLSession(configuration: config)
        let service = UpstreamRateService(session: session)
        var credential = UpstreamRateCredential.empty(host: "ageteam.online", sourceType: .sub2API)
        credential.sub2CookieHeader = "cf_clearance=ok; sub2api_refresh_token=browser"
        credential.sub2RefreshToken = "stale-keychain-token"
        credential.userAgent = "Mozilla/5.0 Chrome/149.0"

        do {
            let outcome = try await service.fetchBalance(credential: credential)
            expectTrue(
                outcome.credential.sub2AuthToken == "access-from-cookie",
                "Sub2API cookie-only refresh should hydrate access token"
            )
            expectTrue(
                outcome.snapshot.balance?.displayAmount == 12.5,
                "Sub2API balance should be read after cookie-only refresh"
            )
            let refresh = Sub2CookieOnlyRefreshProtocol.requests.first { $0.path == "/api/v1/auth/refresh" }
            expectTrue(refresh?.cookie?.contains("sub2api_refresh_token=browser") == true, "refresh request should send browser cookie")
            expectTrue(refresh?.userAgent == "Mozilla/5.0 Chrome/149.0", "refresh request should send browser User-Agent")
            expectTrue(refresh?.body == #"{}"#, "cookie-only refresh should send an empty JSON body")
            expectTrue(
                outcome.credential.sub2CookieHeader.contains("sub2api_refresh_token=rotated"),
                "rotated refresh Cookie should be stored"
            )
            expectFalse(
                outcome.credential.sub2CookieHeader.contains("sub2api_refresh_token=browser"),
                "stale refresh Cookie should be replaced"
            )
            expectTrue(
                outcome.credential.sub2CookieHeader.contains("cf_clearance=ok"),
                "unrelated browser Cookies should be preserved"
            )
            expectTrue(
                outcome.credential.sub2RefreshToken == "rotated",
                "rotated refresh Cookie should update the credential field"
            )
        } catch {
            fail("expected Sub2API cookie-only refresh to succeed, got \(error)")
        }
    }

    private static func testSub2BodyTokenRefreshKeepsRequestBody() async {
        Sub2CookieOnlyRefreshProtocol.requests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Sub2CookieOnlyRefreshProtocol.self]
        let session = URLSession(configuration: config)
        let service = UpstreamRateService(session: session)
        var credential = UpstreamRateCredential.empty(host: "body.example.test", sourceType: .sub2API)
        credential.sub2RefreshToken = "body-refresh"

        do {
            _ = try await service.fetchBalance(credential: credential)
            let refresh = Sub2CookieOnlyRefreshProtocol.requests.first { $0.path == "/api/v1/auth/refresh" }
            expectTrue(refresh?.cookie == nil, "body-token refresh should not require a Cookie")
            expectTrue(
                refresh?.body.contains(#""refresh_token":"body-refresh""#) == true,
                "body-token refresh should preserve the existing request contract"
            )
        } catch {
            fail("expected body-token Sub2API refresh to succeed, got \(error)")
        }
    }

    private static func testCrossOriginRefreshCookieIsRejected() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CrossOriginRefreshProtocol.self]
        let session = URLSession(configuration: config)
        let service = UpstreamRateService(session: session)
        var credential = UpstreamRateCredential.empty(host: "origin.example.test", sourceType: .sub2API)
        credential.sub2CookieHeader = "sub2api_refresh_token=origin"
        credential.sub2RefreshToken = "origin"

        do {
            let outcome = try await service.fetchBalance(credential: credential)
            expectTrue(
                outcome.credential.sub2CookieHeader == "sub2api_refresh_token=origin",
                "cross-origin refresh response must not replace the upstream Cookie"
            )
            expectTrue(
                outcome.credential.sub2RefreshToken == "origin",
                "cross-origin refresh response must not replace the credential field"
            )
        } catch {
            fail("expected cross-origin refresh response to preserve the original Cookie, got \(error)")
        }
    }

    private static func testNewAPIBalanceFallsBackToUserProfile() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NewAPIProfileFallbackProtocol.self]
        let session = URLSession(configuration: config)
        let service = UpstreamRateService(session: session)
        var credential = UpstreamRateCredential.empty(host: "nekocode.ai", sourceType: .newAPI)
        credential.newAPICookieHeader = "session=browser"

        do {
            let outcome = try await service.fetchBalance(credential: credential)
            expectTrue(
                outcome.snapshot.balance?.displayAmount == 14.409,
                "new-api balance should fall back to /api/user/profile when /api/user/self is not the frontend profile endpoint"
            )
        } catch {
            fail("expected new-api profile fallback balance, got \(error)")
        }
    }

    private static func testNekocodeHostIsDetectedAsNewAPI() {
        let detected = UpstreamRateSiteDetector.detect(
            host: "nekocode.ai",
            statusCode: 200,
            headers: [:],
            body: "{\"message\":\"未登录\",\"success\":false}"
        )
        expectTrue(
            detected == .newAPI,
            "nekocode.ai should be treated as a new-api upstream even when unauthenticated body is generic"
        )
    }
}

private final class CloudflareHTMLChallengeProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 403,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Server": "cloudflare",
                "cf-ray": "test-ray"
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("<html>challenge</html>".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class Sub2CookieOnlyRefreshProtocol: URLProtocol {
    struct RequestRecord {
        let path: String
        let cookie: String?
        let userAgent: String?
        let authorization: String?
        let body: String
    }

    static var requests: [RequestRecord] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let bodyData = requestBodyData(request)
        Self.requests.append(
            RequestRecord(
                path: path,
                cookie: request.value(forHTTPHeaderField: "Cookie"),
                userAgent: request.value(forHTTPHeaderField: "User-Agent"),
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                body: String(decoding: bodyData, as: UTF8.self)
            )
        )

        let status: Int
        let body: String
        switch path {
        case "/api/v1/auth/refresh":
            status = 200
            if request.value(forHTTPHeaderField: "Cookie")?.contains("sub2api_refresh_token=") == true {
                body = #"{"code":0,"data":{"access_token":"access-from-cookie","expires_in":3600}}"#
            } else {
                body = #"{"code":0,"data":{"access_token":"access-from-cookie","refresh_token":"body-refresh-next","expires_in":3600}}"#
            }
        case "/api/v1/auth/me":
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer access-from-cookie" {
                status = 200
                body = #"{"code":0,"data":{"balance":12.5}}"#
            } else {
                status = 401
                body = #"{"code":401,"message":"unauthorized"}"#
            }
        default:
            status = 404
            body = #"{"code":404,"message":"not found"}"#
        }

        var responseHeaders = ["Content-Type": "application/json"]
        if path == "/api/v1/auth/refresh",
           request.value(forHTTPHeaderField: "Cookie")?.contains("sub2api_refresh_token=") == true {
            responseHeaders["Set-Cookie"] = "sub2api_refresh_token=rotated; Path=/; HttpOnly; Secure; SameSite=Lax"
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func requestBodyData(_ request: URLRequest) -> Data {
        if let httpBody = request.httpBody {
            return httpBody
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}

private final class CrossOriginRefreshProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let host = request.url?.host ?? ""
        let path = request.url?.path ?? ""
        if host == "origin.example.test", path == "/api/v1/auth/refresh" {
            let redirectURL = URL(string: "https://redirect.example.test/api/v1/auth/refresh")!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": redirectURL.absoluteString]
            )!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: redirectURL), redirectResponse: response)
            return
        }

        let status: Int
        let body: String
        var headers = ["Content-Type": "application/json"]
        if host == "redirect.example.test", path == "/api/v1/auth/refresh" {
            status = 200
            body = #"{"code":0,"data":{"access_token":"redirect-access","expires_in":3600}}"#
            headers["Set-Cookie"] = "sub2api_refresh_token=redirect; Path=/; HttpOnly; Secure"
        } else if host == "origin.example.test", path == "/api/v1/auth/me" {
            status = 200
            body = #"{"code":0,"data":{"balance":1}}"#
        } else {
            status = 404
            body = #"{"code":404,"message":"not found"}"#
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class NewAPIProfileFallbackProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let status: Int
        let body: String
        switch path {
        case "/api/status":
            status = 200
            body = #"{"success":true,"data":{"quota_per_unit":500000}}"#
        case "/api/user/self":
            status = 401
            body = #"{"success":false,"error":{"message":"Missing API key"}}"#
        case "/api/user/profile":
            status = 200
            body = #"{"success":true,"data":{"id":3911,"balance":"14.409"}}"#
        default:
            status = 404
            body = #"{"success":false,"message":"not found"}"#
        }
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
