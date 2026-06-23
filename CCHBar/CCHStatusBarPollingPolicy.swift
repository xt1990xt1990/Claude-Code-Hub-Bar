import Foundation

struct CCHStatusBarPollingPolicy {
    let trailingFastWindow: TimeInterval = 5
    let overviewInterval: TimeInterval = 3

    func shouldRefreshData(
        lastRefresh: Date?,
        hasRunningItems: Bool,
        lastRunningSeenAt: Date?,
        idleInterval: TimeInterval = 3,
        activeInterval: TimeInterval = 1,
        now: Date = Date()
    ) -> Bool {
        guard let lastRefresh else { return true }
        let interval = usesFastPolling(
            hasRunningItems: hasRunningItems,
            lastRunningSeenAt: lastRunningSeenAt,
            now: now
        ) ? activeInterval : idleInterval
        return now.timeIntervalSince(lastRefresh) >= interval
    }

    func shouldRefreshOverview(lastRefresh: Date?, now: Date = Date()) -> Bool {
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= overviewInterval
    }

    private func usesFastPolling(
        hasRunningItems: Bool,
        lastRunningSeenAt: Date?,
        now: Date
    ) -> Bool {
        if hasRunningItems { return true }
        guard let lastRunningSeenAt else { return false }
        return now.timeIntervalSince(lastRunningSeenAt) < trailingFastWindow
    }
}
