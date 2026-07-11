import Foundation

struct CCHUpstreamWakeRefreshCoordinator {
    static let networkSettleDelayNanoseconds: UInt64 = 1_200_000_000

    private(set) var hasPendingWake = false
    private(set) var isRefreshScheduled = false

    mutating func systemDidWake(networkIsSatisfied: Bool) -> Bool {
        guard !isRefreshScheduled else { return false }
        hasPendingWake = true
        return scheduleIfPossible(networkIsSatisfied: networkIsSatisfied)
    }

    mutating func networkDidBecomeSatisfied() -> Bool {
        scheduleIfPossible(networkIsSatisfied: true)
    }

    mutating func networkDidBecomeUnsatisfied() {
        guard isRefreshScheduled else { return }
        hasPendingWake = true
    }

    func shouldWaitForUpstreamOperation(
        rateRefreshIsRunning: Bool,
        balanceRefreshIsRunning: Bool
    ) -> Bool {
        rateRefreshIsRunning || balanceRefreshIsRunning
    }

    mutating func scheduledRefreshCanStart(networkIsSatisfied: Bool) -> Bool {
        guard isRefreshScheduled else { return false }
        guard networkIsSatisfied else {
            hasPendingWake = true
            isRefreshScheduled = false
            return false
        }
        hasPendingWake = false
        return true
    }

    mutating func refreshDidFinish(networkIsSatisfied: Bool) -> Bool {
        isRefreshScheduled = false
        if !networkIsSatisfied {
            hasPendingWake = true
        }
        return scheduleIfPossible(networkIsSatisfied: networkIsSatisfied)
    }

    private mutating func scheduleIfPossible(networkIsSatisfied: Bool) -> Bool {
        guard hasPendingWake, networkIsSatisfied, !isRefreshScheduled else { return false }
        hasPendingWake = false
        isRefreshScheduled = true
        return true
    }
}
