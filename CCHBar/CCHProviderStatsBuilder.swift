import Foundation

struct CCHProviderStatsSnapshot {
    let enabledCount: Int
    let unhealthyCount: Int

    static let empty = CCHProviderStatsSnapshot(enabledCount: 0, unhealthyCount: 0)
}

enum CCHProviderStatsBuilder {
    static func makeSnapshot(providers: [CCHProvider]) -> CCHProviderStatsSnapshot {
        var enabledCount = 0
        var unhealthyCount = 0
        for provider in providers {
            if provider.isEnabled {
                enabledCount += 1
            }
            if isUnhealthy(provider) {
                unhealthyCount += 1
            }
        }

        return CCHProviderStatsSnapshot(
            enabledCount: enabledCount,
            unhealthyCount: unhealthyCount
        )
    }

    static func miniProbeRecordedSampleCount(_ histories: [Int: [CCHProviderMiniProbeSample]]) -> Int {
        histories.values.reduce(0) { $0 + $1.count }
    }

    static func isUnhealthy(_ provider: CCHProvider) -> Bool {
        provider.health.circuitState.lowercased() != "closed" || provider.health.failureCount > 0
    }
}
