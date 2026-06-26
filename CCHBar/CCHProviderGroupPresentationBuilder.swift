import Foundation

struct CCHProviderGroupPresentationInput: Equatable {
    let providerId: Int
    let groupTag: String
    let overrideNames: Set<String>?
}

struct CCHProviderGroupPresentationSnapshot {
    let assignedGroupNames: Set<String>
    let displayGroupTitles: [String]
}

enum CCHProviderGroupPresentationBuilder {
    static func makeSnapshot(_ input: CCHProviderGroupPresentationInput) -> CCHProviderGroupPresentationSnapshot {
        let assigned = input.overrideNames ?? storedGroupNames(from: input.groupTag)
        let titles = assigned
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return CCHProviderGroupPresentationSnapshot(
            assignedGroupNames: assigned,
            displayGroupTitles: titles.isEmpty ? ["默认"] : titles
        )
    }

    static func storedGroupNames(from groupTag: String) -> Set<String> {
        Set(providerGroupTitles(groupTag).filter { !isDefaultProviderGroup($0) })
    }
}
