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
    }
}
