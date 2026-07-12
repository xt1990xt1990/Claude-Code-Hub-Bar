import CoreGraphics
import Darwin

@main
private struct ProviderSearchFocusGlowTests {
    static func main() {
        let focused = CCHProviderSearchFocusGlowStyle.resolve(isFocused: true, reduceMotion: false)
        expectEqual(focused.strokeOpacity, 0.88, "focused state should show the blue ring")
        expectEqual(focused.glowOpacity, 0.26, "focused state should use the restrained glow")
        expectEqual(focused.scale, 1.01, "focused state should expand by one percent")
        expectEqual(focused.duration, 0.22, "focus should use the 0.22 second ease-out transition")

        let blurred = CCHProviderSearchFocusGlowStyle.resolve(isFocused: false, reduceMotion: false)
        expectEqual(blurred.strokeOpacity, 0, "blurred state should hide the ring")
        expectEqual(blurred.glowOpacity, 0, "blurred state should hide the glow")
        expectEqual(blurred.scale, 1, "blurred state should return to neutral scale")
        expectEqual(blurred.duration, 0.16, "blur should use the 0.16 second transition")

        let reduced = CCHProviderSearchFocusGlowStyle.resolve(isFocused: true, reduceMotion: true)
        expectEqual(reduced.scale, 1, "reduced motion should disable scaling")
        expectEqual(reduced.duration, 0.12, "reduced motion should use the short opacity transition")
        expectEqual(reduced.strokeOpacity, focused.strokeOpacity, "reduced motion should retain focus visibility")
        expectEqual(reduced.glowOpacity, focused.glowOpacity, "reduced motion should retain the glow")
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
