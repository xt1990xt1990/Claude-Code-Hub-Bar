import Foundation

struct UpstreamRateAutoSyncTiming {
    static func clampedIntervalHours(_ hours: Double) -> Double {
        min(
            max(hours, 1),
            72
        )
    }

    static func intervalSeconds(hours: Double) -> TimeInterval {
        clampedIntervalHours(hours) * 60 * 60
    }

    static func nextRunEpoch(
        now: Date,
        intervalHours: Double,
        existingNextRunEpoch: Double
    ) -> Double {
        let interval = intervalSeconds(hours: intervalHours)
        if existingNextRunEpoch > 0 {
            return existingNextRunEpoch
        }
        return now.addingTimeInterval(interval).timeIntervalSince1970
    }

    static func shouldRun(now: Date, nextRunEpoch: Double) -> Bool {
        nextRunEpoch > 0 && now.timeIntervalSince1970 >= nextRunEpoch
    }
}
