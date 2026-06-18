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

struct UpstreamRateSnapshot: Codable, Equatable {
    let host: String
    let sourceType: UpstreamRateSourceType
    let status: UpstreamRateSourceStatus
    let entries: [UpstreamRateEntry]

    init(host: String, sourceType: UpstreamRateSourceType, status: UpstreamRateSourceStatus, entries: [UpstreamRateEntry] = []) {
        self.host = normalizedUpstreamHost(host) ?? host.lowercased()
        self.sourceType = sourceType
        self.status = status
        self.entries = entries
    }

    static func mergeLatest(cached: [UpstreamRateSnapshot], refreshed: [UpstreamRateSnapshot]) -> [UpstreamRateSnapshot] {
        var merged = Dictionary(uniqueKeysWithValues: cached.map { ($0.host, $0) })
        for snapshot in refreshed {
            if
                let previous = merged[snapshot.host],
                previous.status == .available,
                !previous.entries.isEmpty,
                snapshot.status != .available,
                snapshot.entries.isEmpty {
                continue
            }
            merged[snapshot.host] = snapshot
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
    let sourceType: UpstreamRateSourceType
    let matchStatus: UpstreamRateMatchStatus
    let isSelectedForSync: Bool
    let isEnabled: Bool

    var id: Int { providerId }

    var hasRateChange: Bool {
        guard let upstreamRate else { return false }
        return abs(currentRate - upstreamRate) > 0.0001
    }

    var canSync: Bool {
        matchStatus == .matched && isSelectedForSync && upstreamRate != nil
    }
}

struct UpstreamRateSite: Identifiable, Equatable {
    let host: String
    let displayName: String
    let sourceType: UpstreamRateSourceType
    let status: UpstreamRateSourceStatus
    let section: UpstreamRateSection
    let rows: [UpstreamRateProviderRow]

    var id: String { host }

    var syncableRows: [UpstreamRateProviderRow] {
        rows.filter(\.canSync)
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
}

enum UpstreamRateMatcher {
    static func buildSites(
        providers: [UpstreamRateProviderInput],
        snapshots: [UpstreamRateSnapshot],
        selectedProviderIds: Set<Int>,
        ignoredHosts: Set<String>
    ) -> [UpstreamRateSite] {
        let snapshotsByHost = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.host, $0) })
        let grouped = Dictionary(grouping: providers) { provider in
            providerHost(provider) ?? "unknown-\(provider.id)"
        }

        return grouped.map { host, values in
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
                        selectedProviderIds: selectedProviderIds
                    )
                }

            return UpstreamRateSite(
                host: host,
                displayName: displayName(for: host),
                sourceType: sourceType,
                status: status,
                section: section(sourceType: sourceType, status: status),
                rows: rows
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
        selectedProviderIds: Set<Int>
    ) -> UpstreamRateProviderRow {
        let entry = snapshot?.entries.first { $0.providerId == provider.id }
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
            sourceType: sourceType,
            matchStatus: matchStatus,
            isSelectedForSync: selectedProviderIds.contains(provider.id),
            isEnabled: provider.isEnabled
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
        if status == .available {
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

    private static func displayName(for host: String) -> String {
        host
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

    if host.hasPrefix("www.") {
        return String(host.dropFirst(4))
    }
    return host
}
