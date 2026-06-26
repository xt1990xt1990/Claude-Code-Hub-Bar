import Foundation

func providerMiniProbeIsDue(
    lastRunAt: Date?,
    intervalMinutes: Double,
    now: Date = Date()
) -> Bool {
    guard let lastRunAt else { return true }
    let intervalSeconds = max(0, intervalMinutes) * 60
    guard intervalSeconds > 0 else { return true }
    return now.timeIntervalSince(lastRunAt) >= intervalSeconds
}

func providerMiniProbeFailureBackoffSeconds(
    failureCount: Int,
    intervalMinutes: Double
) -> TimeInterval {
    let intervalSeconds = max(0, intervalMinutes) * 60
    guard intervalSeconds > 0 else { return 60 }
    let failureBackoff: TimeInterval
    switch failureCount {
    case ..<2:
        failureBackoff = 60
    case 2:
        failureBackoff = 120
    default:
        failureBackoff = 300
    }
    return min(failureBackoff, intervalSeconds)
}

func providerMiniProbeSuccessTTFBMs(isSuccess: Bool, ttfbMs: Double?) -> Double? {
    isSuccess ? ttfbMs : nil
}

func providerMiniProbeAverageSuccessTTFB<T>(
    _ samples: [T],
    maxCount: Int,
    isSuccess: (T) -> Bool,
    ttfbMs: (T) -> Double?
) -> Double? {
    let values = samples
        .compactMap { sample -> Double? in
            guard isSuccess(sample) else { return nil }
            return ttfbMs(sample)
        }
        .suffix(max(0, maxCount))
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}
