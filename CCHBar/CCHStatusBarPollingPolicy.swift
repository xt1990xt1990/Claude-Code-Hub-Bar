import Foundation

struct CCHRefreshFreshnessPolicy {
    let ttl: TimeInterval

    func shouldRefresh(
        lastSuccessful: Date?,
        now: Date = Date(),
        force: Bool = false
    ) -> Bool {
        guard !force, let lastSuccessful else { return true }
        return now.timeIntervalSince(lastSuccessful) >= ttl
    }
}

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
        let interval = dataRefreshInterval(
            hasRunningItems: hasRunningItems,
            lastRunningSeenAt: lastRunningSeenAt,
            idleInterval: idleInterval,
            activeInterval: activeInterval,
            now: now
        )
        return now.timeIntervalSince(lastRefresh) >= interval
    }

    func dataRefreshInterval(
        hasRunningItems: Bool,
        lastRunningSeenAt: Date?,
        idleInterval: TimeInterval = 3,
        activeInterval: TimeInterval = 1,
        now: Date = Date()
    ) -> TimeInterval {
        usesFastPolling(
            hasRunningItems: hasRunningItems,
            lastRunningSeenAt: lastRunningSeenAt,
            now: now
        ) ? activeInterval : idleInterval
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
