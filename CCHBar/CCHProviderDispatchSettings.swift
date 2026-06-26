import Foundation

struct CCHProviderDispatchSettings: Equatable {
    let priority: Int
    let weight: Int

    init?(priority: Int, weight: Int) {
        guard priority >= 0, weight >= 0 else { return nil }
        self.priority = priority
        self.weight = weight
    }

    init?(priorityText: String, weightText: String) {
        guard
            let priority = Self.parseNonNegativeInt(priorityText),
            let weight = Self.parseNonNegativeInt(weightText)
        else {
            return nil
        }
        self.init(priority: priority, weight: weight)
    }

    var patchBody: [String: Any] {
        [
            "priority": priority,
            "weight": weight
        ]
    }

    private static func parseNonNegativeInt(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.allSatisfy(\.isNumber), let parsed = Int(trimmed) else { return nil }
        return parsed >= 0 ? parsed : nil
    }
}

struct CCHProviderSortDescriptor: Equatable {
    let id: Int
    let isEnabled: Bool
    let hasMiniProbe: Bool
}

enum CCHProviderSortMode {
    case commitSorted
    case preserveCurrentOrder
}

struct CCHProviderSortState {
    private var currentProviderIds: [Int] = []
    private(set) var hasPendingSort = false

    mutating func order<T>(
        _ providers: [T],
        mode: CCHProviderSortMode,
        descriptor: (T) -> CCHProviderSortDescriptor
    ) -> [T] {
        let sortedProviders = sortProvidersByOperationalPriority(providers, descriptor: descriptor)
        let sortedProviderIds = sortedProviders.map { descriptor($0).id }

        guard mode == .preserveCurrentOrder, !currentProviderIds.isEmpty else {
            currentProviderIds = sortedProviderIds
            hasPendingSort = false
            return sortedProviders
        }

        var providerById: [Int: T] = [:]
        let incomingProviderIds = providers.map { provider in
            let id = descriptor(provider).id
            providerById[id] = provider
            return id
        }
        let incomingProviderIdSet = Set(incomingProviderIds)
        let retainedProviderIds = currentProviderIds.filter { incomingProviderIdSet.contains($0) }
        let retainedProviderIdSet = Set(retainedProviderIds)
        let appendedProviderIds = incomingProviderIds.filter { !retainedProviderIdSet.contains($0) }
        let preservedProviderIds = retainedProviderIds + appendedProviderIds

        currentProviderIds = preservedProviderIds
        hasPendingSort = preservedProviderIds != sortedProviderIds
        return preservedProviderIds.compactMap { providerById[$0] }
    }

    mutating func commitIfPending<T>(
        _ providers: [T],
        descriptor: (T) -> CCHProviderSortDescriptor
    ) -> [T]? {
        guard hasPendingSort else { return nil }
        return order(providers, mode: .commitSorted, descriptor: descriptor)
    }
}

func sortProvidersByOperationalPriority<T>(
    _ providers: [T],
    descriptor: (T) -> CCHProviderSortDescriptor
) -> [T] {
    providers.enumerated()
        .sorted { lhs, rhs in
            let lhsDescriptor = descriptor(lhs.element)
            let rhsDescriptor = descriptor(rhs.element)
            if lhsDescriptor.isEnabled != rhsDescriptor.isEnabled {
                return lhsDescriptor.isEnabled && !rhsDescriptor.isEnabled
            }
            if lhsDescriptor.hasMiniProbe != rhsDescriptor.hasMiniProbe {
                return lhsDescriptor.hasMiniProbe && !rhsDescriptor.hasMiniProbe
            }
            return lhs.offset < rhs.offset
        }
        .map(\.element)
}
