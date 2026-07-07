import Foundation

@main
private struct UpstreamRateSub2CloudflareCookieTests {
    @MainActor
    static func main() async throws {
        try testSub2BrowserImportStoresCookieHeader()
        try testSub2BrowserImportAcceptsCookieOnlyRefreshToken()
        try await testSub2CookieOnlyLoginUsesValidator()
        try testSub2HeadersIncludeBrowserCookie()
        try testNewAPIHeadersIncludeBrowserCookieAndUserAgent()
        try testNewAPICookieOnlyHeadersUseBrowserUserAgentFallback()
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
        let credential = UpstreamRateCredential.empty(host: "ageteam.online", sourceType: .sub2API)
        let next = try importer.mergeBrowserState(
            (
                storage: [:],
                cookieHeader: "sub2api_refresh_token=browser",
                userAgent: "Mozilla/5.0 Chrome/149.0"
            ),
            into: credential
        )

        try expect(next.sub2CookieHeader == "sub2api_refresh_token=browser", "Sub2API cookie-only refresh token should be stored")
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
