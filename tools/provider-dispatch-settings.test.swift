import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    guard actual == expected else {
        fail("\(message). Expected \(expected), got \(actual)")
    }
}

private func expectNil<T>(_ value: T?, _ message: String) {
    guard value == nil else { fail(message) }
}

private func expectNotNil<T>(_ value: T?, _ message: String) -> T {
    guard let value else { fail(message) }
    return value
}

@main
private struct ProviderDispatchSettingsTests {
    static func main() {
        let parsed = expectNotNil(
            CCHProviderDispatchSettings(priorityText: " 2 ", weightText: "10"),
            "valid non-negative integer inputs should parse"
        )
        expectEqual(parsed.priority, 2, "priority should be parsed from text")
        expectEqual(parsed.weight, 10, "weight should be parsed from text")
        expectEqual(parsed.patchBody["priority"] as? Int, 2, "PATCH body should use priority")
        expectEqual(parsed.patchBody["weight"] as? Int, 10, "PATCH body should use weight")

        expectNil(
            CCHProviderDispatchSettings(priorityText: "-1", weightText: "1"),
            "negative priority should be rejected"
        )
        expectNil(
            CCHProviderDispatchSettings(priorityText: "1.5", weightText: "1"),
            "decimal priority should be rejected"
        )
        expectNil(
            CCHProviderDispatchSettings(priorityText: "1", weightText: ""),
            "empty weight should be rejected"
        )

        let sortedIds = sortProvidersByOperationalPriority(
            [
                CCHProviderSortDescriptor(id: 1, isEnabled: false, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 2, isEnabled: true, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 3, isEnabled: false, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 4, isEnabled: true, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 5, isEnabled: false, hasMiniProbe: false)
            ],
            descriptor: { $0 }
        ).map(\.id)
        expectEqual(
            sortedIds,
            [4, 2, 3, 1, 5],
            "enabled providers should come first, mini-probe providers second, then stable original order"
        )

        var sortState = CCHProviderSortState()
        let committedIds = sortState.order(
            [
                CCHProviderSortDescriptor(id: 1, isEnabled: false, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 2, isEnabled: true, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 3, isEnabled: false, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 4, isEnabled: true, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 5, isEnabled: false, hasMiniProbe: false)
            ],
            mode: .commitSorted,
            descriptor: { $0 }
        ).map(\.id)
        expectEqual(
            committedIds,
            [4, 2, 3, 1, 5],
            "committing provider sort should use operational priority order"
        )
        expectEqual(sortState.hasPendingSort, false, "committed sort should not leave pending state")

        let preservedIds = sortState.order(
            [
                CCHProviderSortDescriptor(id: 1, isEnabled: true, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 2, isEnabled: true, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 3, isEnabled: false, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 4, isEnabled: true, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 5, isEnabled: false, hasMiniProbe: false)
            ],
            mode: .preserveCurrentOrder,
            descriptor: { $0 }
        ).map(\.id)
        expectEqual(
            preservedIds,
            [4, 2, 3, 1, 5],
            "preserving provider sort should keep the row in place after inline state changes"
        )
        expectEqual(sortState.hasPendingSort, true, "preserved changed sort should mark pending state")

        let closeBoundaryCommittedIds = expectNotNil(
            sortState.commitIfPending(
                [
                    CCHProviderSortDescriptor(id: 1, isEnabled: true, hasMiniProbe: false),
                    CCHProviderSortDescriptor(id: 2, isEnabled: true, hasMiniProbe: false),
                    CCHProviderSortDescriptor(id: 3, isEnabled: false, hasMiniProbe: true),
                    CCHProviderSortDescriptor(id: 4, isEnabled: true, hasMiniProbe: true),
                    CCHProviderSortDescriptor(id: 5, isEnabled: false, hasMiniProbe: false)
                ],
                descriptor: { $0 }
            ),
            "closing a provider card should commit pending provider sort"
        ).map(\.id)
        expectEqual(
            closeBoundaryCommittedIds,
            [4, 1, 2, 3, 5],
            "closing a provider card with pending sort should move rows to the latest operational priority order"
        )
        expectEqual(sortState.hasPendingSort, false, "closing a provider card should clear pending sort state")

        let noPendingCloseBoundaryCommit = sortState.commitIfPending(
            [
                CCHProviderSortDescriptor(id: 1, isEnabled: true, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 2, isEnabled: true, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 3, isEnabled: false, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 4, isEnabled: true, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 5, isEnabled: false, hasMiniProbe: false)
            ],
            descriptor: { $0 }
        )
        expectNil(noPendingCloseBoundaryCommit, "closing a provider card without pending sort should be a no-op")

        let recommittedIds = sortState.order(
            [
                CCHProviderSortDescriptor(id: 1, isEnabled: true, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 2, isEnabled: true, hasMiniProbe: false),
                CCHProviderSortDescriptor(id: 3, isEnabled: false, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 4, isEnabled: true, hasMiniProbe: true),
                CCHProviderSortDescriptor(id: 5, isEnabled: false, hasMiniProbe: false)
            ],
            mode: .commitSorted,
            descriptor: { $0 }
        ).map(\.id)
        expectEqual(
            recommittedIds,
            [4, 1, 2, 3, 5],
            "committing a pending sort should move rows to the latest operational priority order"
        )
        expectEqual(sortState.hasPendingSort, false, "recommitted sort should clear pending state")
    }
}
