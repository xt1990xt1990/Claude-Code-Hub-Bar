import Foundation

enum CCHProviderNameSearch {
    static func isActive(_ query: String) -> Bool {
        !normalized(query).isEmpty
    }

    static func filter<Value>(
        _ values: [Value],
        query: String,
        name: (Value) -> String
    ) -> [Value] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return values }
        return values.filter { normalized(name($0)).contains(needle) }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
