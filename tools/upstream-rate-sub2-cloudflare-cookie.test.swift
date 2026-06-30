import Foundation

@main
private struct UpstreamRateSub2CloudflareCookieTests {
    @MainActor
    static func main() throws {
        try testSub2BrowserImportStoresCookieHeader()
        try testSub2HeadersIncludeBrowserCookie()
        try testNewAPIHeadersIncludeBrowserCookieAndUserAgent()
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

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw NSError(domain: "UpstreamRateSub2CloudflareCookieTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
