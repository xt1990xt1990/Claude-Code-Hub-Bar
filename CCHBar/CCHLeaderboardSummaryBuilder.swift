import Foundation

enum CCHLeaderboardSummaryBuilder {
    static func makeSummary(from entries: [CCHLeaderboardEntry]) -> CCHLeaderboardSummary {
        var requests = 0
        var cost: Double = 0
        var tokens = 0
        var totalInputTokens = 0
        var weightedCacheHitRate: Double = 0

        for entry in entries {
            requests += entry.requests
            cost += entry.cost
            tokens += entry.tokens

            if let cacheHitRate = entry.cacheHitRateOverride, entry.inputTokens > 0 {
                totalInputTokens += entry.inputTokens
                weightedCacheHitRate += cacheHitRate * Double(entry.inputTokens)
            }
        }

        let cacheHitRate: Double?
        if totalInputTokens > 0 {
            cacheHitRate = min(1, max(0, weightedCacheHitRate / Double(totalInputTokens)))
        } else {
            cacheHitRate = nil
        }

        return CCHLeaderboardSummary(
            requests: requests,
            cost: cost,
            tokens: tokens,
            cacheHitRate: cacheHitRate
        )
    }
}
