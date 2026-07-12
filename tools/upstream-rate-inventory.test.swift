import Darwin
import Foundation

@main
private struct UpstreamRateInventoryTests {
    static func main() async {
        testInventoryMatchPriority()
        await testSub2Inventory()
        await testNewAPIInventory()
        await testNewAPIRevealFailureFallsBackToVariantInventory()
    }

    private static func testInventoryMatchPriority() {
        let inventory = UpstreamRateKeyInventory(
            values: ["sk-first-1234", "sk-second-1234"],
            key: { $0 },
            normalize: normalizeSub2Key,
            suffix: sub2KeySuffix
        )
        expect(
            inventory.match(for: "sk-first-1234") == "sk-first-1234",
            "complete key matches should take priority over suffix candidates"
        )
        expect(
            inventory.match(for: "sk-unknown-1234") == nil,
            "ambiguous suffix candidates should not select an arbitrary key"
        )
    }

    private static func testSub2Inventory() async {
        InventoryProtocol.keyRequestCount = 0
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InventoryProtocol.self]
        let service = UpstreamRateService(session: URLSession(configuration: configuration))

        var credential = UpstreamRateCredential.empty(host: "sub.inventory.test", sourceType: .sub2API)
        credential.baseURL = "https://sub.inventory.test"
        credential.sub2AuthToken = "access-token"
        credential.sub2TokenExpiresAt = Date().addingTimeInterval(3_600)

        let targets = [
            UpstreamRateTarget(providerId: 1, providerName: "First", apiKey: "sk-first-1234"),
            UpstreamRateTarget(providerId: 2, providerName: "Second", apiKey: "sk-second-5678")
        ]

        do {
            let outcome = try await service.fetchSnapshot(credential: credential, targets: targets)
            expect(outcome.snapshot.entries.count == 2, "one inventory should match every target on the host")
            expect(InventoryProtocol.keyRequestCount == 1, "all targets on one host should share one key pagination scan")
        } catch {
            fail("expected one host inventory refresh to succeed, got \(error)")
        }
    }

    private static func testNewAPIInventory() async {
        InventoryProtocol.tokenRequestCount = 0
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InventoryProtocol.self]
        let service = UpstreamRateService(session: URLSession(configuration: configuration))

        var credential = UpstreamRateCredential.empty(host: "new.inventory.test", sourceType: .newAPI)
        credential.baseURL = "https://new.inventory.test"
        credential.newAPIAccessToken = "access-token"
        credential.newAPIUserId = "42"

        let targets = [
            UpstreamRateTarget(providerId: 1, providerName: "First", apiKey: "sk-first-1234"),
            UpstreamRateTarget(providerId: 2, providerName: "Second", apiKey: "sk-second-5678")
        ]

        do {
            let outcome = try await service.fetchSnapshot(credential: credential, targets: targets)
            expect(outcome.snapshot.entries.count == 2, "one new-api inventory should match every target on the host")
            expect(InventoryProtocol.tokenRequestCount == 1, "all targets on one host should share one new-api token pagination scan")
        } catch {
            fail("expected one new-api inventory refresh to succeed, got \(error)")
        }
    }

    private static func testNewAPIRevealFailureFallsBackToVariantInventory() async {
        RevealFailureFallbackProtocol.variantRequestCount = 0
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RevealFailureFallbackProtocol.self]
        let service = UpstreamRateService(session: URLSession(configuration: configuration))

        var credential = UpstreamRateCredential.empty(host: "variant.inventory.test", sourceType: .newAPI)
        credential.baseURL = "https://variant.inventory.test"
        credential.newAPIAccessToken = "access-token"
        credential.newAPIUserId = "42"

        do {
            let outcome = try await service.fetchSnapshot(
                credential: credential,
                targets: [
                    UpstreamRateTarget(
                        providerId: 7,
                        providerName: "Variant",
                        apiKey: "sk-target-1234"
                    )
                ]
            )
            expect(outcome.snapshot.entries.count == 1, "a failed regular reveal should fall back to variant tokens")
            expect(outcome.snapshot.entries.first?.providerId == 7, "the variant token should match the provider")
            expect(outcome.snapshot.entries.first?.rate == 0.4, "the variant token ratio should be preserved")
            expect(RevealFailureFallbackProtocol.variantRequestCount == 1, "variant inventory should be requested once")
        } catch {
            fail("expected variant fallback after reveal failure, got \(error)")
        }
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private final class InventoryProtocol: URLProtocol {
    static var keyRequestCount = 0
    static var tokenRequestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        if path == "/api/v1/keys" {
            Self.keyRequestCount += 1
        }
        if path == "/api/token/search" {
            Self.tokenRequestCount += 1
        }

        let payload: [String: Any]
        switch path {
        case "/api/v1/auth/me":
            payload = ["code": 0, "data": ["balance": 10.0]]
        case "/api/v1/groups/rates":
            payload = ["code": 0, "data": ["1": 0.7]]
        case "/api/v1/keys":
            payload = [
                "code": 0,
                "data": [
                    "items": [
                        [
                            "id": 1,
                            "key": "sk-first-1234",
                            "name": "First",
                            "group_id": 1,
                            "group": ["id": 1, "name": "standard", "balance_charge_rate": 0.5]
                        ],
                        [
                            "id": 2,
                            "key": "sk-second-5678",
                            "name": "Second",
                            "group_id": 1,
                            "group": ["id": 1, "name": "standard", "balance_charge_rate": 0.5]
                        ]
                    ],
                    "total": 2,
                    "page_size": 100
                ]
            ]
        case "/api/status":
            payload = ["success": true, "data": ["quota_per_unit": 500_000]]
        case "/api/user/self":
            payload = ["success": true, "data": ["id": 42, "quota": 10_000_000]]
        case "/api/user/self/groups":
            payload = ["success": true, "data": ["standard": ["ratio": 0.7]]]
        case "/api/token/search":
            payload = [
                "success": true,
                "data": [
                    "items": [
                        ["id": 1, "key": "sk-first-1234", "name": "First", "group": "standard"],
                        ["id": 2, "key": "sk-second-5678", "name": "Second", "group": "standard"]
                    ],
                    "total": 2,
                    "size": 100
                ]
            ]
        default:
            payload = path.hasPrefix("/api/v1/")
                ? ["code": 0, "data": [:]]
                : ["success": true, "data": [:]]
        }

        let data = try! JSONSerialization.data(withJSONObject: payload)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class RevealFailureFallbackProtocol: URLProtocol {
    static var variantRequestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let payload: [String: Any]
        let statusCode: Int

        switch path {
        case "/api/status":
            statusCode = 200
            payload = ["success": true, "data": ["quota_per_unit": 500_000]]
        case "/api/user/self":
            statusCode = 200
            payload = ["success": true, "data": ["id": 42, "quota": 10_000_000]]
        case "/api/user/self/groups":
            statusCode = 200
            payload = ["success": true, "data": ["standard": ["ratio": 0.7]]]
        case "/api/token/search":
            statusCode = 200
            payload = [
                "success": true,
                "data": [
                    "items": [
                        ["id": 99, "key": "sk-targ****1234", "name": "Masked", "group": "standard"]
                    ],
                    "total": 1,
                    "size": 100
                ]
            ]
        case "/api/token/99/key":
            statusCode = 500
            payload = ["success": false, "message": "reveal unavailable"]
        case "/api/token":
            Self.variantRequestCount += 1
            statusCode = 200
            payload = [
                "success": true,
                "data": [
                    "items": [
                        [
                            "id": 7,
                            "key": "sk-target-1234",
                            "name": "Variant",
                            "billing_type": "pay_as_you_go",
                            "pay_as_you_go_group": ["name": "variant", "ratio": 0.4]
                        ]
                    ],
                    "total": 1,
                    "size": 100
                ]
            ]
        default:
            statusCode = 200
            payload = ["success": true, "data": [:]]
        }

        let data = try! JSONSerialization.data(withJSONObject: payload)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
