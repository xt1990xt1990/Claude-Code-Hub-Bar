import Darwin
import Foundation

@main
private struct ProviderSearchFocusPolicyTests {
    static func main() {
        let searchFrame = CGRect(x: 100, y: 20, width: 150, height: 28)

        expectEqual(
            CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: true,
                searchFrame: searchFrame,
                tapLocation: CGPoint(x: 90, y: 30)
            ),
            true,
            "a focused search should dismiss after an outside tap"
        )
        expectEqual(
            CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: true,
                searchFrame: searchFrame,
                tapLocation: CGPoint(x: 125, y: 30)
            ),
            false,
            "a tap inside the complete search control should keep focus"
        )
        expectEqual(
            CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: false,
                searchFrame: searchFrame,
                tapLocation: CGPoint(x: 90, y: 30)
            ),
            false,
            "an unfocused search needs no dismissal"
        )
        expectEqual(
            CCHProviderSearchFocusPolicy.shouldDismiss(
                isFocused: true,
                searchFrame: .zero,
                tapLocation: CGPoint(x: 90, y: 30)
            ),
            false,
            "an unavailable layout frame must not dismiss focus"
        )
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
