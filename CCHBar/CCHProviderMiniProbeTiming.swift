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
