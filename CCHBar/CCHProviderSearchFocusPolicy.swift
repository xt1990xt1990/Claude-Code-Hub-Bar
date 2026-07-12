import CoreGraphics

enum CCHProviderSearchFocusPolicy {
    static func shouldDismiss(
        isFocused: Bool,
        searchFrame: CGRect,
        tapLocation: CGPoint
    ) -> Bool {
        isFocused && !searchFrame.isEmpty && !searchFrame.contains(tapLocation)
    }
}
