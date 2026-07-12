import Foundation

@main
private struct RefreshFreshnessPolicyTests {
    static func main() {
        let policy = CCHRefreshFreshnessPolicy(ttl: 10)
        let now = Date(timeIntervalSince1970: 1_000)

        expect(
            policy.shouldRefresh(lastSuccessful: nil, now: now),
            "a refresh with no successful history should run"
        )
        expect(
            !policy.shouldRefresh(lastSuccessful: now.addingTimeInterval(-9), now: now),
            "a refresh inside its TTL should be reused"
        )
        expect(
            policy.shouldRefresh(lastSuccessful: now.addingTimeInterval(-10), now: now),
            "a refresh at the TTL boundary should run"
        )
        expect(
            policy.shouldRefresh(lastSuccessful: now, now: now.addingTimeInterval(1), force: true),
            "a forced refresh should ignore the TTL"
        )
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
