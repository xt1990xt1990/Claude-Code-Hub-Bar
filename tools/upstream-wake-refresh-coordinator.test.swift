import Darwin
import Foundation

@main
private struct UpstreamWakeRefreshCoordinatorTests {
    static func main() {
        var coordinator = CCHUpstreamWakeRefreshCoordinator()
        expect(!coordinator.systemDidWake(networkIsSatisfied: false), "offline wake waits")
        expect(coordinator.hasPendingWake, "offline wake stays pending")
        expect(coordinator.networkDidBecomeSatisfied(), "network restoration schedules")
        expect(!coordinator.networkDidBecomeSatisfied(), "duplicate network event is coalesced")
        expect(
            !coordinator.systemDidWake(networkIsSatisfied: true),
            "duplicate wake is coalesced while scheduled"
        )
        _ = coordinator.refreshDidFinish(networkIsSatisfied: true)
        expect(coordinator.systemDidWake(networkIsSatisfied: true), "later wake schedules again")
        expect(
            coordinator.shouldWaitForUpstreamOperation(
                rateRefreshIsRunning: true,
                balanceRefreshIsRunning: false
            ),
            "rate refresh blocks wake refresh"
        )
        expect(
            coordinator.shouldWaitForUpstreamOperation(
                rateRefreshIsRunning: false,
                balanceRefreshIsRunning: true
            ),
            "balance refresh blocks wake refresh"
        )
        expect(
            !coordinator.shouldWaitForUpstreamOperation(
                rateRefreshIsRunning: false,
                balanceRefreshIsRunning: false
            ),
            "wake refresh starts when upstream operations are idle"
        )
        expect(
            coordinator.scheduledRefreshCanStart(networkIsSatisfied: true),
            "scheduled refresh starts while online"
        )
        coordinator.networkDidBecomeUnsatisfied()
        expect(coordinator.hasPendingWake, "network loss while scheduled restores pending")
        expect(
            !coordinator.networkDidBecomeSatisfied(),
            "network restoration waits for scheduled refresh to finish"
        )
        expect(
            coordinator.refreshDidFinish(networkIsSatisfied: true),
            "completion reschedules after an in-flight network interruption"
        )
        expect(!coordinator.hasPendingWake, "rescheduled refresh consumes pending wake")
        expect(coordinator.isRefreshScheduled, "retry remains scheduled")
        expect(
            !coordinator.refreshDidFinish(networkIsSatisfied: false),
            "offline completion waits for a future network restoration"
        )
        expect(coordinator.hasPendingWake, "offline completion keeps pending wake")
        expect(coordinator.networkDidBecomeSatisfied(), "future network restoration schedules retry")
        expect(
            !coordinator.scheduledRefreshCanStart(networkIsSatisfied: false),
            "scheduled refresh does not start while offline"
        )
        expect(coordinator.hasPendingWake, "offline start keeps pending wake")
        expect(coordinator.networkDidBecomeSatisfied(), "restoration schedules after offline start")
        expect(coordinator.scheduledRefreshCanStart(networkIsSatisfied: true), "retry starts online")
        _ = coordinator.refreshDidFinish(networkIsSatisfied: true)
        expect(!coordinator.hasPendingWake, "completion clears pending")
        expect(!coordinator.isRefreshScheduled, "completion clears scheduled")
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
