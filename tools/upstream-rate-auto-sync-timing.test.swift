import Foundation

@main
struct UpstreamRateAutoSyncTimingTest {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000)

        assertEqual(
            UpstreamRateAutoSyncTiming.clampedIntervalHours(0.2),
            1,
            "interval is clamped to the minimum"
        )
        assertEqual(
            UpstreamRateAutoSyncTiming.clampedIntervalHours(80),
            72,
            "interval is clamped to the maximum"
        )
        assertEqual(
            UpstreamRateAutoSyncTiming.nextRunEpoch(now: now, intervalHours: 2, existingNextRunEpoch: 0),
            8_200,
            "first schedule starts from now plus interval"
        )
        assertEqual(
            UpstreamRateAutoSyncTiming.nextRunEpoch(now: now, intervalHours: 2, existingNextRunEpoch: 1_200),
            1_200,
            "existing absolute schedule is preserved"
        )
        assertEqual(
            UpstreamRateAutoSyncTiming.shouldRun(now: now, nextRunEpoch: 1_001),
            false,
            "does not run before the scheduled wall-clock time"
        )
        assertEqual(
            UpstreamRateAutoSyncTiming.shouldRun(now: now, nextRunEpoch: 999),
            true,
            "runs when the scheduled wall-clock time is overdue"
        )
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            fputs("Assertion failed: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
