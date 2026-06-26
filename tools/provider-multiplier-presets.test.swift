import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    guard actual == expected else {
        fail("\(message). Expected \(expected), got \(actual)")
    }
}

@main
private struct ProviderMultiplierPresetTests {
    static func main() {
        expectEqual(
            providerMultiplierQuickValues(upstreamRate: nil),
            [0, 0.05, 0.1, 0.2, 0.5, 1, 2],
            "plain provider multiplier editor should keep the default absolute presets"
        )

        expectEqual(
            providerMultiplierQuickValues(upstreamRate: 0.15),
            [0.15, 0.18, 0.23, 0.27, 0.30, 0.33, 0.38],
            "upstream multiplier presets should use markup factors rounded to two decimals"
        )

        expectEqual(
            providerMultiplierQuickValues(upstreamRate: 0),
            [0, 0.05, 0.1, 0.2, 0.5, 1, 2],
            "zero upstream multiplier should fall back to absolute presets"
        )
    }
}
