import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func expectTrue(_ condition: Bool, _ message: String) {
    guard condition else { fail(message) }
}

private func expectFalse(_ condition: Bool, _ message: String) {
    guard !condition else { fail(message) }
}

private func provider(_ id: Int, _ name: String) -> UpstreamRateProviderInput {
    UpstreamRateProviderInput(
        id: id,
        name: name,
        apiURL: "https://sub.example.com/v1",
        websiteURL: "https://sub.example.com",
        groupTag: "default",
        costMultiplier: 0.05,
        isEnabled: true
    )
}

@main
private struct UpstreamRateStaleSnapshotTests {
    static func main() {
        let providers = [
            provider(1, "Example-Codex"),
            provider(2, "Example-Codex-Plus"),
            provider(3, "Example-Codex-Group1"),
            provider(4, "Example-Codex-Pro")
        ]
        let staleSnapshot = UpstreamRateSnapshot(
            host: "sub.example.com",
            sourceType: .sub2API,
            status: .available,
            entries: [
                UpstreamRateEntry(providerId: 1, keyName: "Example-Codex", groupName: "codex", rate: 0.05),
                UpstreamRateEntry(providerId: 2, keyName: "Example-Codex-Plus", groupName: "plus", rate: 0.05),
                UpstreamRateEntry(providerId: 3, keyName: "Example-Codex-Group1", groupName: "group1", rate: 0.05)
            ]
        )
        let freshSnapshot = UpstreamRateSnapshot(
            host: "sub.example.com",
            sourceType: .sub2API,
            status: .available,
            entries: staleSnapshot.entries + [
                UpstreamRateEntry(providerId: 4, keyName: "Example-Codex-Pro", groupName: "codex", rate: 0.05)
            ],
            balance: UpstreamBalanceSnapshot(displayAmount: 100)
        )

        expectTrue(
            shouldRefreshUpstreamRateSnapshotsOnActivation(providers: providers, snapshots: []),
            "opening the upstream tab with no cached snapshot should trigger an initial refresh"
        )
        expectTrue(
            shouldRecordUpstreamBalanceRefreshSuccess(totalHostCount: 2, completedHostCount: 2),
            "a completed balance batch should advance its freshness timestamp"
        )
        expectFalse(
            shouldRecordUpstreamBalanceRefreshSuccess(totalHostCount: 2, completedHostCount: 1),
            "a partially failed balance batch should remain retryable"
        )
        expectFalse(
            shouldRecordUpstreamBalanceRefreshSuccess(totalHostCount: 1, completedHostCount: 0),
            "a failed balance batch should remain retryable"
        )
        expectTrue(
            shouldRefreshUpstreamRateSnapshots(providers: providers, snapshots: [staleSnapshot]),
            "missing provider id in an available snapshot should trigger refresh"
        )
        expectFalse(
            shouldRefreshUpstreamRateSnapshots(providers: providers, snapshots: [freshSnapshot]),
            "snapshot with all current provider ids should not trigger refresh"
        )

        let upstreamDeltaSite = UpstreamRateMatcher.buildSites(
            providers: providers,
            snapshots: [freshSnapshot],
            selectedProviderIds: [],
            ignoredHosts: [],
            previousUpstreamRatesByProviderId: [1: 0.03, 2: 0.05]
        ).first { $0.host == "sub.example.com" }
        let increasedUpstreamRow = upstreamDeltaSite?.rows.first { $0.providerId == 1 }
        expectTrue(
            increasedUpstreamRow?.previousUpstreamRate == 0.03,
            "matched row should expose previous upstream rate for changed upstream snapshot entries"
        )
        let unchangedUpstreamRow = upstreamDeltaSite?.rows.first { $0.providerId == 2 }
        expectTrue(
            unchangedUpstreamRow?.previousUpstreamRate == nil,
            "matched row should suppress previous upstream rate when upstream snapshot rate is unchanged"
        )
        expectTrue(
            changedPreviousUpstreamRatesByProviderId(
                previousSnapshots: [staleSnapshot],
                currentSnapshots: [freshSnapshot]
            ) == [:],
            "previous upstream rate map should stay empty when overlapping snapshot entries are unchanged"
        )
        let changedSnapshot = UpstreamRateSnapshot(
            host: "sub.example.com",
            sourceType: .sub2API,
            status: .available,
            entries: [
                UpstreamRateEntry(providerId: 1, keyName: "Example-Codex", groupName: "codex", rate: 0.08),
                UpstreamRateEntry(providerId: 2, keyName: "Example-Codex-Plus", groupName: "plus", rate: 0.05)
            ]
        )
        expectTrue(
            changedPreviousUpstreamRatesByProviderId(
                previousSnapshots: [staleSnapshot],
                currentSnapshots: [changedSnapshot]
            ) == [1: 0.05],
            "previous upstream rate map should include only changed provider entries"
        )
        expectTrue(
            formatMultiplierDelta(0.2) == "+0.20x",
            "positive upstream rate deltas should use signed suffix notation"
        )
        expectTrue(
            formatMultiplierDelta(-0.05) == "-0.05x",
            "negative upstream rate deltas should use signed suffix notation"
        )
        expectTrue(
            upstreamRateComparisonSymbol(currentRate: 1.3, upstreamRate: 1.0) == ">",
            "current rate above upstream rate should render as a greater-than comparison"
        )
        expectTrue(
            upstreamRateComparisonSymbol(currentRate: 0.8, upstreamRate: 1.0) == "<",
            "current rate below upstream rate should render as a less-than comparison"
        )
        expectTrue(
            upstreamRateComparisonSymbol(currentRate: 1.0, upstreamRate: 1.00001) == "=",
            "nearly equal current and upstream rates should render as equality"
        )

        expectTrue(
            upstreamRateProviderSnapshotSignature(providers: providers)
                != upstreamRateProviderSnapshotSignature(providers: Array(providers.prefix(3))),
            "adding a provider should change the upstream rate provider signature"
        )
        expectTrue(
            normalizedUpstreamHost("https://www.example-upstream.test/") == "www.example-upstream.test",
            "upstream rate host normalization should preserve www-only upstream domains"
        )
        expectTrue(
            UpstreamRateMatcher.providerHost(
                UpstreamRateProviderInput(
                    id: 10,
                    name: "Example Upstream",
                    apiURL: "https://api.example-upstream.test/v1",
                    websiteURL: "https://www.example-upstream.test/",
                    groupTag: "default",
                    costMultiplier: 1,
                    isEnabled: true
                )
            ) == "www.example-upstream.test",
            "upstream rate provider grouping should keep the configured website host"
        )

        let pendingSelectionSite = UpstreamRateMatcher.buildSites(
            providers: providers,
            snapshots: [staleSnapshot],
            selectedProviderIds: [4],
            ignoredHosts: []
        ).first { $0.host == "sub.example.com" }
        guard let pendingSelectionRow = pendingSelectionSite?.rows.first(where: { $0.providerId == 4 }) else {
            fail("expected unmatched provider row to be present")
        }
        expectTrue(
            pendingSelectionRow.isSelectableForSync,
            "unmatched provider should allow sync selection so checking it can refresh snapshot"
        )
        expectTrue(
            pendingSelectionRow.isSelectedForSync,
            "unmatched provider should preserve pending sync selection"
        )
        expectFalse(
            pendingSelectionRow.canSync,
            "unmatched provider should not sync until a refreshed snapshot matches it"
        )

        let unsupportedSite = UpstreamRateMatcher.buildSites(
            providers: [
                UpstreamRateProviderInput(
                    id: 5,
                    name: "Unknown",
                    apiURL: "https://unknown.example.com/v1",
                    websiteURL: "https://unknown.example.com",
                    groupTag: "default",
                    costMultiplier: 1,
                    isEnabled: true
                )
            ],
            snapshots: [],
            selectedProviderIds: [],
            ignoredHosts: []
        ).first
        guard let unsupportedRow = unsupportedSite?.rows.first else {
            fail("expected unsupported provider row to be present")
        }
        expectFalse(
            unsupportedRow.isSelectableForSync,
            "unsupported provider should stay unselectable"
        )

        let authExpiredSnapshot = UpstreamRateSnapshot(
            host: "sub.example.com",
            sourceType: .sub2API,
            status: .authExpired
        )
        let authExpiredMerged = UpstreamRateSnapshot.mergeLatest(
            cached: [freshSnapshot],
            refreshed: [authExpiredSnapshot]
        )
        expectTrue(
            authExpiredMerged.first?.status == .authExpired,
            "auth-expired snapshot should replace stale available snapshot so UI can show reauthorization"
        )
        expectTrue(
            authExpiredMerged.first?.entries.count == freshSnapshot.entries.count,
            "auth-expired snapshot should preserve previous key matches"
        )
        expectTrue(
            authExpiredMerged.first?.balance == freshSnapshot.balance,
            "auth-expired snapshot should preserve previous balance"
        )
        let authExpiredSite = UpstreamRateMatcher.buildSites(
            providers: providers,
            snapshots: authExpiredMerged,
            selectedProviderIds: [4],
            ignoredHosts: []
        ).first { $0.host == "sub.example.com" }
        expectTrue(
            authExpiredSite?.section == .syncable,
            "auth-expired site should stay in the top syncable section while showing reauthorization state"
        )
        expectTrue(
            authExpiredSite?.syncableRows.isEmpty == true,
            "auth-expired site should not sync using preserved stale entries"
        )

        let transientFailureSnapshot = UpstreamRateSnapshot(
            host: "sub.example.com",
            sourceType: .sub2API,
            status: .needsLogin
        )
        let transientFailureMerged = UpstreamRateSnapshot.mergeLatest(
            cached: [freshSnapshot],
            refreshed: [transientFailureSnapshot]
        )
        expectTrue(
            transientFailureMerged.first?.status == .available,
            "transient needs-login snapshot should keep existing available data"
        )
    }
}
