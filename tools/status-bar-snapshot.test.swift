import Foundation

@main
struct StatusBarSnapshotTest {
    static func main() {
        let earlier = CCHStatusBarSnapshot(
            showsDetails: true,
            reducedMotion: false,
            idlePrimary: "TTL $0.00",
            idleDetail: "0 req",
            idleCacheState: .normal,
            runningItems: [],
            hasRecentLogs: false,
            generatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let later = CCHStatusBarSnapshot(
            showsDetails: true,
            reducedMotion: false,
            idlePrimary: "TTL $0.00",
            idleDetail: "0 req",
            idleCacheState: .normal,
            runningItems: [],
            hasRecentLogs: false,
            generatedAt: Date(timeIntervalSince1970: 2_000)
        )

        assertEqual(
            earlier == later,
            true,
            "status bar snapshot equality should ignore generatedAt to avoid no-op UI updates"
        )
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            fputs("Assertion failed: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
