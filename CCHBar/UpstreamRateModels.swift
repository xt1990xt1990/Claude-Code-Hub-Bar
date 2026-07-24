import Foundation

enum UpstreamRateSourceType: String, Codable, Equatable {
    case sub2API
    case newAPI
    case unknown

    var title: String {
        switch self {
        case .sub2API: return "Sub2API"
        case .newAPI: return "new-api"
        case .unknown: return "其他官网"
        }
    }
}

enum UpstreamRateSourceStatus: String, Codable, Equatable {
    case available
    case needsLogin
    case authExpired
    case unsupported
}

enum UpstreamRateMatchStatus: String, Codable, Equatable {
    case matched
    case unmatched
    case unsupported
}

enum UpstreamRateSection: String, Codable, Equatable {
    case syncable
    case needsConfiguration
    case unsupported
}

struct UpstreamRateProviderInput: Identifiable, Equatable {
    let id: Int
    let name: String
    let apiURL: String
    let websiteURL: String
    let groupTag: String
    let costMultiplier: Double
    let isEnabled: Bool
}

struct UpstreamRateEntry: Codable, Equatable {
    let providerId: Int?
    let keyName: String
    let groupName: String
    let rate: Double

    init(providerId: Int? = nil, keyName: String, groupName: String, rate: Double) {
        self.providerId = providerId
        self.keyName = keyName
        self.groupName = groupName
        self.rate = rate
    }
}

struct UpstreamBalanceSnapshot: Codable, Equatable {
    let displayAmount: Double
    let unit: String
    let rawAmount: Double?
    let usedDisplayAmount: Double?
    let totalRechargedDisplayAmount: Double?

    init(
        displayAmount: Double,
        unit: String = "USD",
        rawAmount: Double? = nil,
        usedDisplayAmount: Double? = nil,
        totalRechargedDisplayAmount: Double? = nil
    ) {
        self.displayAmount = displayAmount
        self.unit = unit
        self.rawAmount = rawAmount
        self.usedDisplayAmount = usedDisplayAmount
        self.totalRechargedDisplayAmount = totalRechargedDisplayAmount
    }
}

struct UpstreamRateSnapshot: Codable, Equatable {
    let host: String
    let sourceType: UpstreamRateSourceType
    let status: UpstreamRateSourceStatus
    let entries: [UpstreamRateEntry]
    let balance: UpstreamBalanceSnapshot?

    init(
        host: String,
        sourceType: UpstreamRateSourceType,
        status: UpstreamRateSourceStatus,
        entries: [UpstreamRateEntry] = [],
        balance: UpstreamBalanceSnapshot? = nil
    ) {
        self.host = normalizedUpstreamHost(host) ?? host.lowercased()
        self.sourceType = sourceType
        self.status = status
        self.entries = entries
        self.balance = balance
    }

    static func mergeLatest(cached: [UpstreamRateSnapshot], refreshed: [UpstreamRateSnapshot]) -> [UpstreamRateSnapshot] {
        var merged = Dictionary(uniqueKeysWithValues: cached.map { ($0.host, $0) })
        for snapshot in refreshed {
            if snapshot.status == .authExpired, let previous = merged[snapshot.host] {
                merged[snapshot.host] = UpstreamRateSnapshot(
                    host: previous.host,
                    sourceType: previous.sourceType,
                    status: .authExpired,
                    entries: previous.entries,
                    balance: previous.balance
                )
                continue
            }
            if
                let previous = merged[snapshot.host],
                previous.status == .available,
                !previous.entries.isEmpty,
                snapshot.status != .available,
                snapshot.status != .authExpired,
                snapshot.entries.isEmpty {
                continue
            }
            if let previous = merged[snapshot.host], snapshot.balance == nil {
                merged[snapshot.host] = UpstreamRateSnapshot(
                    host: snapshot.host,
                    sourceType: snapshot.sourceType,
                    status: snapshot.status,
                    entries: snapshot.entries,
                    balance: previous.balance
                )
            } else {
                merged[snapshot.host] = snapshot
            }
        }
        return merged.values.sorted { $0.host.localizedCaseInsensitiveCompare($1.host) == .orderedAscending }
    }

    static func mergeBalances(cached: [UpstreamRateSnapshot], balances: [UpstreamRateSnapshot]) -> [UpstreamRateSnapshot] {
        var merged = Dictionary(uniqueKeysWithValues: cached.map { ($0.host, $0) })
        for snapshot in balances where snapshot.balance != nil {
            if let previous = merged[snapshot.host] {
                merged[snapshot.host] = UpstreamRateSnapshot(
                    host: previous.host,
                    sourceType: previous.sourceType,
                    status: snapshot.status,
                    entries: previous.entries,
                    balance: snapshot.balance
                )
            } else {
                merged[snapshot.host] = snapshot
            }
        }
        return merged.values.sorted { $0.host.localizedCaseInsensitiveCompare($1.host) == .orderedAscending }
    }
}

struct UpstreamRateProviderRow: Identifiable, Equatable {
    let providerId: Int
    let providerName: String
    let host: String
    let groupTag: String
    let currentRate: Double
    let upstreamGroupName: String?
    let upstreamRate: Double?
    let previousUpstreamRate: Double?
    let sourceType: UpstreamRateSourceType
    let matchStatus: UpstreamRateMatchStatus
    let isSelectedForSync: Bool
    let isEnabled: Bool
    let wasAdjustedInLastSync: Bool

    var id: Int { providerId }

    var hasRateChange: Bool {
        guard let upstreamRate else { return false }
        return abs(currentRate - upstreamRate) > 0.0001
    }

    var canSync: Bool {
        matchStatus == .matched && isSelectedForSync && upstreamRate != nil
    }

    var isSelectableForSync: Bool {
        matchStatus != .unsupported
    }

    var shouldRefreshSnapshotOnSyncSelection: Bool {
        matchStatus == .unmatched
    }
}

struct UpstreamRateSite: Identifiable, Equatable {
    let host: String
    let displayName: String
    let sourceType: UpstreamRateSourceType
    let status: UpstreamRateSourceStatus
    let section: UpstreamRateSection
    let rows: [UpstreamRateProviderRow]
    let balance: UpstreamBalanceSnapshot?

    var id: String { host }

    var syncableRows: [UpstreamRateProviderRow] {
        guard status == .available else { return [] }
        return rows.filter(\.canSync)
    }

    var matchedCount: Int {
        rows.filter { $0.matchStatus == .matched }.count
    }

    var selectedCount: Int {
        rows.filter(\.isSelectedForSync).count
    }

    var pendingSyncCount: Int {
        syncableRows.filter(\.hasRateChange).count
    }

    var lastSyncAdjustedCount: Int {
        rows.filter(\.wasAdjustedInLastSync).count
    }
}

enum UpstreamRateMatcher {
    static func buildSites(
        providers: [UpstreamRateProviderInput],
        snapshots: [UpstreamRateSnapshot],
        selectedProviderIds: Set<Int>,
        ignoredHosts: Set<String>,
        displayNames: [String: String] = [:],
        lastSyncAdjustedProviderIds: Set<Int> = [],
        previousUpstreamRatesByProviderId: [Int: Double] = [:]
    ) -> [UpstreamRateSite] {
        let snapshotsByHost = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.host, $0) })
        let grouped = Dictionary(grouping: providers) { provider in
            providerHost(provider) ?? "unknown-\(provider.id)"
        }

        return grouped.compactMap { host, values in
            if ignoredHosts.contains(host) {
                return nil
            }
            let snapshot = snapshotsByHost[host]
            let sourceType = snapshot?.sourceType ?? inferredSourceType(host: host)
            let status = resolvedStatus(sourceType: sourceType, snapshot: snapshot, ignoredHosts: ignoredHosts, host: host)
            let rows = values
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { provider in
                    buildRow(
                        provider: provider,
                        host: host,
                        sourceType: sourceType,
                        status: status,
                        snapshot: snapshot,
                        selectedProviderIds: selectedProviderIds,
                        lastSyncAdjustedProviderIds: lastSyncAdjustedProviderIds,
                        previousUpstreamRatesByProviderId: previousUpstreamRatesByProviderId
                    )
                }

            return UpstreamRateSite(
                host: host,
                displayName: displayName(for: host, customNames: displayNames),
                sourceType: sourceType,
                status: status,
                section: section(sourceType: sourceType, status: status),
                rows: rows,
                balance: snapshot?.balance
            )
        }
        .sorted { lhs, rhs in
            if lhs.section != rhs.section {
                return sectionRank(lhs.section) < sectionRank(rhs.section)
            }
            return lhs.host.localizedCaseInsensitiveCompare(rhs.host) == .orderedAscending
        }
    }

    static func providerHost(_ provider: UpstreamRateProviderInput) -> String? {
        normalizedUpstreamHost(provider.websiteURL) ?? normalizedUpstreamHost(provider.apiURL)
    }

    private static func buildRow(
        provider: UpstreamRateProviderInput,
        host: String,
        sourceType: UpstreamRateSourceType,
        status: UpstreamRateSourceStatus,
        snapshot: UpstreamRateSnapshot?,
        selectedProviderIds: Set<Int>,
        lastSyncAdjustedProviderIds: Set<Int>,
        previousUpstreamRatesByProviderId: [Int: Double]
    ) -> UpstreamRateProviderRow {
        let entry = snapshot?.entries.first { $0.providerId == provider.id }
        let previousRate = previousUpstreamRatesByProviderId[provider.id]
        let visiblePreviousRate: Double?
        if let currentRate = entry?.rate,
           let previousRate,
           abs(currentRate - previousRate) > 0.0001 {
            visiblePreviousRate = previousRate
        } else {
            visiblePreviousRate = nil
        }
        let unsupported = sourceType == .unknown || status == .unsupported
        let matchStatus: UpstreamRateMatchStatus
        if unsupported {
            matchStatus = .unsupported
        } else if entry != nil {
            matchStatus = .matched
        } else {
            matchStatus = .unmatched
        }

        return UpstreamRateProviderRow(
            providerId: provider.id,
            providerName: provider.name,
            host: host,
            groupTag: provider.groupTag,
            currentRate: provider.costMultiplier,
            upstreamGroupName: entry?.groupName,
            upstreamRate: entry?.rate,
            previousUpstreamRate: visiblePreviousRate,
            sourceType: sourceType,
            matchStatus: matchStatus,
            isSelectedForSync: selectedProviderIds.contains(provider.id),
            isEnabled: provider.isEnabled,
            wasAdjustedInLastSync: lastSyncAdjustedProviderIds.contains(provider.id)
        )
    }

    private static func resolvedStatus(
        sourceType: UpstreamRateSourceType,
        snapshot: UpstreamRateSnapshot?,
        ignoredHosts: Set<String>,
        host: String
    ) -> UpstreamRateSourceStatus {
        if ignoredHosts.contains(host) || sourceType == .unknown {
            return .unsupported
        }
        return snapshot?.status ?? .needsLogin
    }

    private static func section(sourceType: UpstreamRateSourceType, status: UpstreamRateSourceStatus) -> UpstreamRateSection {
        if sourceType == .unknown || status == .unsupported {
            return .unsupported
        }
        if status == .available || status == .authExpired {
            return .syncable
        }
        return .needsConfiguration
    }

    private static func inferredSourceType(host: String) -> UpstreamRateSourceType {
        let lowercased = host.lowercased()
        if lowercased.contains("sub2") || lowercased.hasPrefix("sub.") {
            return .sub2API
        }
        return .unknown
    }

    private static func displayName(for host: String, customNames: [String: String]) -> String {
        let normalizedHost = normalizedUpstreamHost(host) ?? host.lowercased()
        let customName = customNames[normalizedHost] ?? customNames[host]
        let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? host : trimmed
    }

    private static func sectionRank(_ section: UpstreamRateSection) -> Int {
        switch section {
        case .syncable: return 0
        case .needsConfiguration: return 1
        case .unsupported: return 2
        }
    }
}

func normalizedUpstreamHost(_ rawValue: String) -> String? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let valueWithScheme: String
    if trimmed.contains("://") {
        valueWithScheme = trimmed
    } else {
        valueWithScheme = "https://\(trimmed)"
    }

    guard let url = URL(string: valueWithScheme), let host = url.host?.lowercased() else {
        return nil
    }

    return host
}

func shouldRefreshUpstreamRateSnapshots(
    providers: [UpstreamRateProviderInput],
    snapshots: [UpstreamRateSnapshot]
) -> Bool {
    let snapshotsByHost = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.host, $0) })
    let providersByHost = Dictionary(grouping: providers) { provider in
        UpstreamRateMatcher.providerHost(provider) ?? "unknown-\(provider.id)"
    }

    for (host, providers) in providersByHost {
        guard let snapshot = snapshotsByHost[host], snapshot.status == .available else { continue }
        let matchedProviderIds = Set(snapshot.entries.compactMap(\.providerId))
        let currentProviderIds = Set(providers.map(\.id))
        if !currentProviderIds.isSubset(of: matchedProviderIds) {
            return true
        }
    }

    return false
}

func shouldRefreshUpstreamRateSnapshotsOnActivation(
    providers: [UpstreamRateProviderInput],
    snapshots: [UpstreamRateSnapshot]
) -> Bool {
    snapshots.isEmpty || shouldRefreshUpstreamRateSnapshots(providers: providers, snapshots: snapshots)
}

func shouldRecordUpstreamBalanceRefreshSuccess(
    totalHostCount: Int,
    completedHostCount: Int
) -> Bool {
    totalHostCount > 0 && completedHostCount == totalHostCount
}

func isCompleteUpstreamRateTargetLoad(providerCount: Int, loadedTargetCount: Int) -> Bool {
    providerCount > 0 && loadedTargetCount == providerCount
}

func shouldPrunePersistedProviderState(providerIds: Set<Int>) -> Bool {
    !providerIds.isEmpty
}

func pendingSelectedUpstreamRateRows(in sites: [UpstreamRateSite]) -> [UpstreamRateProviderRow] {
    sites.flatMap(\.syncableRows).filter(\.hasRateChange)
}

func shouldSchedulePendingUpstreamRateSync(
    pendingSyncCount: Int,
    isRefreshingRates: Bool,
    isSyncingRates: Bool,
    hasScheduledTask: Bool
) -> Bool {
    pendingSyncCount > 0
        && !isRefreshingRates
        && !isSyncingRates
        && !hasScheduledTask
}

func changedPreviousUpstreamRatesByProviderId(
    previousSnapshots: [UpstreamRateSnapshot],
    currentSnapshots: [UpstreamRateSnapshot]
) -> [Int: Double] {
    let previousEntries = Dictionary(
        uniqueKeysWithValues: previousSnapshots.flatMap(\.entries).compactMap { entry -> (Int, Double)? in
            guard let providerId = entry.providerId else { return nil }
            return (providerId, entry.rate)
        }
    )
    let currentEntries = Dictionary(
        uniqueKeysWithValues: currentSnapshots.flatMap(\.entries).compactMap { entry -> (Int, Double)? in
            guard let providerId = entry.providerId else { return nil }
            return (providerId, entry.rate)
        }
    )

    return currentEntries.reduce(into: [Int: Double]()) { result, entry in
        guard let previousRate = previousEntries[entry.key] else { return }
        guard abs(entry.value - previousRate) > 0.0001 else { return }
        result[entry.key] = previousRate
    }
}

func formatMultiplierDelta(_ value: Double) -> String {
    let sign = value >= 0 ? "+" : "-"
    return String(format: "\(sign)%.2fx", abs(value))
}

func upstreamRateComparisonSymbol(currentRate: Double, upstreamRate: Double) -> String {
    if abs(currentRate - upstreamRate) < 0.0001 {
        return "="
    }
    return currentRate > upstreamRate ? ">" : "<"
}

func upstreamRateProviderSnapshotSignature(providers: [UpstreamRateProviderInput]) -> String {
    providers
        .map { provider in
            let host = UpstreamRateMatcher.providerHost(provider) ?? "unknown-\(provider.id)"
            return "\(host)#\(provider.id)"
        }
        .sorted()
        .joined(separator: "|")
}
