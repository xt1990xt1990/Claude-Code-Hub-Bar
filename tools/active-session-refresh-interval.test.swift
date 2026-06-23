import Foundation

@main
struct ActiveSessionRefreshIntervalTest {
    static func main() {
        assertEqual(
            CCHActiveSessionRefreshInterval.allowedIdleSeconds,
            [1, 3, 5],
            "idle refresh interval offers only the supported presets"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.allowedActiveSeconds,
            [1, 3],
            "active refresh interval offers only the supported presets"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedIdleSeconds(1),
            1,
            "one-second idle interval is preserved"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedIdleSeconds(3),
            3,
            "three-second idle interval is preserved"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedIdleSeconds(5),
            5,
            "five-second idle interval is preserved"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedIdleSeconds(0),
            3,
            "invalid low idle interval falls back to the default"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedIdleSeconds(2),
            3,
            "unsupported idle interval falls back to the default"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedIdleSeconds(8),
            3,
            "invalid high idle interval falls back to the default"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedActiveSeconds(1),
            1,
            "one-second active interval is preserved"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedActiveSeconds(3),
            3,
            "three-second active interval is preserved"
        )
        assertEqual(
            CCHActiveSessionRefreshInterval.sanitizedActiveSeconds(5),
            1,
            "unsupported active interval falls back to the default"
        )
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual != expected {
            fputs("Assertion failed: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
