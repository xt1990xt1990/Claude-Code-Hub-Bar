import Foundation

@main
struct StatusBarPollingPolicyTest {
    static func main() {
        let policy = CCHStatusBarPollingPolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        assertEqual(
            policy.shouldRefreshData(
                lastRefresh: nil,
                hasRunningItems: false,
                lastRunningSeenAt: nil,
                idleInterval: 5,
                activeInterval: 3,
                now: now
            ),
            true,
            "missing refresh history should refresh immediately"
        )
        assertEqual(
            policy.shouldRefreshData(
                lastRefresh: now.addingTimeInterval(-4),
                hasRunningItems: false,
                lastRunningSeenAt: nil,
                idleInterval: 5,
                activeInterval: 3,
                now: now
            ),
            false,
            "idle polling should wait for the configured idle interval"
        )
        assertEqual(
            policy.shouldRefreshData(
                lastRefresh: now.addingTimeInterval(-5),
                hasRunningItems: false,
                lastRunningSeenAt: nil,
                idleInterval: 5,
                activeInterval: 3,
                now: now
            ),
            true,
            "idle polling should refresh at the configured idle interval"
        )
        assertEqual(
            policy.shouldRefreshData(
                lastRefresh: now.addingTimeInterval(-2),
                hasRunningItems: true,
                lastRunningSeenAt: nil,
                idleInterval: 5,
                activeInterval: 3,
                now: now
            ),
            false,
            "active polling should wait for the configured active interval"
        )
        assertEqual(
            policy.shouldRefreshData(
                lastRefresh: now.addingTimeInterval(-3),
                hasRunningItems: true,
                lastRunningSeenAt: nil,
                idleInterval: 5,
                activeInterval: 3,
                now: now
            ),
            true,
            "active polling should refresh at the configured active interval"
        )
        assertEqual(
            policy.shouldRefreshData(
                lastRefresh: now.addingTimeInterval(-3),
                hasRunningItems: false,
                lastRunningSeenAt: now.addingTimeInterval(-2),
                idleInterval: 5,
                activeInterval: 3,
                now: now
            ),
            true,
            "recently active status bar should keep the active interval briefly after work ends"
        )
        assertEqual(
            policy.dataRefreshInterval(
                hasRunningItems: false,
                lastRunningSeenAt: nil,
                idleInterval: 1,
                activeInterval: 3,
                now: now
            ),
            1,
            "recent-log freshness should honor a one-second idle polling interval"
        )
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            fputs("Assertion failed: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
