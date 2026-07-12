import Darwin
import Foundation

private struct Item {
    let id: Int
    let name: String
}

@main
private struct ProviderNameSearchTests {
    static func main() {
        let items = [
            Item(id: 1, name: "K12-Codex"),
            Item(id: 2, name: "codex plus"),
            Item(id: 3, name: "Café Claude")
        ]

        expectEqual(
            CCHProviderNameSearch.filter(items, query: "  CODEX ", name: \.name).map(\.id),
            [1, 2],
            "search should trim whitespace and ignore case"
        )
        expectEqual(
            CCHProviderNameSearch.filter(items, query: "cafe", name: \.name).map(\.id),
            [3],
            "search should ignore diacritics"
        )
        expectEqual(
            CCHProviderNameSearch.filter(items, query: "   ", name: \.name).map(\.id),
            [1, 2, 3],
            "blank search should preserve the input"
        )
        expectEqual(
            CCHProviderNameSearch.filter([items[1]], query: "codex", name: \.name).map(\.id),
            [2],
            "search should never add values outside its group-filtered input"
        )
        expectEqual(CCHProviderNameSearch.isActive("  "), false, "blank search should be inactive")
        expectEqual(CCHProviderNameSearch.isActive(" codex "), true, "text search should be active")
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
