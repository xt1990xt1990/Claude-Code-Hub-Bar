import Foundation

struct CCHUpstreamRateSitesSnapshotInput: Equatable {
    let providers: [UpstreamRateProviderInput]
    let snapshots: [UpstreamRateSnapshot]
    let selectedProviderIds: Set<Int>
    let ignoredHosts: Set<String>
    let displayNames: [String: String]
    let lastSyncAdjustedProviderIds: Set<Int>
    let previousUpstreamRatesByProviderId: [Int: Double]
}

struct CCHUpstreamRateSitesSnapshot {
    let sites: [UpstreamRateSite]
    let syncableSites: [UpstreamRateSite]
    let needsConfigurationSites: [UpstreamRateSite]
    let unsupportedSites: [UpstreamRateSite]
    let checkedSyncCount: Int
    let pendingSyncCount: Int
}

enum CCHUpstreamRateSitesSnapshotBuilder {
    static func makeSnapshot(_ input: CCHUpstreamRateSitesSnapshotInput) -> CCHUpstreamRateSitesSnapshot {
        let sites = UpstreamRateMatcher.buildSites(
            providers: input.providers,
            snapshots: input.snapshots,
            selectedProviderIds: input.selectedProviderIds,
            ignoredHosts: input.ignoredHosts,
            displayNames: input.displayNames,
            lastSyncAdjustedProviderIds: input.lastSyncAdjustedProviderIds,
            previousUpstreamRatesByProviderId: input.previousUpstreamRatesByProviderId
        )

        return CCHUpstreamRateSitesSnapshot(
            sites: sites,
            syncableSites: sites.filter { $0.section == .syncable },
            needsConfigurationSites: sites.filter { $0.section == .needsConfiguration },
            unsupportedSites: sites.filter { $0.section == .unsupported },
            checkedSyncCount: sites.flatMap(\.syncableRows).count,
            pendingSyncCount: sites.reduce(0) { $0 + $1.pendingSyncCount }
        )
    }
}
