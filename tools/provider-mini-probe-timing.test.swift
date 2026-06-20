import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func expectTrue(_ value: Bool, _ message: String) {
    guard value else { fail(message) }
}

private func expectFalse(_ value: Bool, _ message: String) {
    guard !value else { fail(message) }
}

@main
private struct ProviderMiniProbeTimingTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000)

        expectTrue(
            providerMiniProbeIsDue(lastRunAt: nil, intervalMinutes: 30, now: now),
            "first run should be due when no sample exists"
        )
        expectFalse(
            providerMiniProbeIsDue(lastRunAt: now.addingTimeInterval(-60), intervalMinutes: 30, now: now),
            "recent run should not be due"
        )
        expectTrue(
            providerMiniProbeIsDue(lastRunAt: now.addingTimeInterval(-1_800), intervalMinutes: 30, now: now),
            "run should be due at the configured interval"
        )

        expectEqual(
            providerMiniProbeFailureBackoffSeconds(failureCount: 1, intervalMinutes: 30),
            60,
            "first failure backs off for one minute"
        )
        expectEqual(
            providerMiniProbeFailureBackoffSeconds(failureCount: 2, intervalMinutes: 30),
            120,
            "second failure backs off for two minutes"
        )
        expectEqual(
            providerMiniProbeFailureBackoffSeconds(failureCount: 3, intervalMinutes: 30),
            300,
            "third failure backs off for five minutes"
        )
        expectEqual(
            providerMiniProbeFailureBackoffSeconds(failureCount: 3, intervalMinutes: 2),
            120,
            "failure backoff is capped by configured interval"
        )

        expectEqual(
            providerMiniProbeSuccessTTFBMs(isSuccess: true, ttfbMs: 468),
            468,
            "successful probe keeps first-byte timing"
        )
        expectNil(
            providerMiniProbeSuccessTTFBMs(isSuccess: false, ttfbMs: 468),
            "failed probe should not expose first-byte timing"
        )
    }
}

private func expectEqual(_ actual: TimeInterval, _ expected: TimeInterval, _ message: String) {
    guard abs(actual - expected) < 0.001 else {
        fail("\(message): expected \(expected), got \(actual)")
    }
}

private func expectEqual(_ actual: Double?, _ expected: Double, _ message: String) {
    guard let actual, abs(actual - expected) < 0.001 else {
        fail("\(message): expected \(expected), got \(String(describing: actual))")
    }
}

private func expectNil(_ actual: Double?, _ message: String) {
    guard actual == nil else {
        fail("\(message): expected nil, got \(String(describing: actual))")
    }
}
