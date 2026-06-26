import Foundation

struct CCHProviderFilterGroupsInput: Equatable {
    let providers: [CCHProviderGroupPresentationInput]
}

struct CCHAssignableProviderGroupsInput: Equatable {
    let officialGroups: [CCHProviderGroup]
    let providerGroupTags: [String]
}

enum CCHProviderGroupsBuilder {
    static func filterGroups(_ input: CCHProviderFilterGroupsInput) -> [String] {
        let groups = Set(input.providers.flatMap { input in
            CCHProviderGroupPresentationBuilder.makeSnapshot(input).displayGroupTitles
        })
        return ["全部"] + groups.filter { $0 != "全部" }.sorted()
    }

    static func assignableGroups(_ input: CCHAssignableProviderGroupsInput) -> [CCHProviderGroup] {
        var seen = Set<String>()
        var merged: [CCHProviderGroup] = []

        for group in input.officialGroups {
            let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.lowercased()
            guard !name.isEmpty, !isDefaultProviderGroup(name), seen.insert(key).inserted else { continue }
            merged.append(group)
        }

        let existingGroups = input.providerGroupTags
            .flatMap { providerGroupTitles($0) }
            .filter { !isDefaultProviderGroup($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        for name in existingGroups {
            let key = name.lowercased()
            guard seen.insert(key).inserted else { continue }
            merged.append(CCHProviderGroup(id: name, name: name, providerCount: nil, costMultiplier: nil))
        }

        return merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
