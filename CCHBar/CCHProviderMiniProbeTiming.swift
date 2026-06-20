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
