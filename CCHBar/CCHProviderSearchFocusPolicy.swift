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

struct CCHProviderSearchFocusGlowStyle: Equatable {
    let strokeOpacity: Double
    let glowOpacity: Double
    let scale: CGFloat
    let duration: Double

    static func resolve(isFocused: Bool, reduceMotion: Bool) -> Self {
        if reduceMotion {
            return Self(
                strokeOpacity: isFocused ? 0.88 : 0,
                glowOpacity: isFocused ? 0.26 : 0,
                scale: 1,
                duration: 0.12
            )
        }

        return Self(
            strokeOpacity: isFocused ? 0.88 : 0,
            glowOpacity: isFocused ? 0.26 : 0,
            scale: isFocused ? 1.01 : 1,
            duration: isFocused ? 0.22 : 0.16
        )
    }
}
