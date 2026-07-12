import AppKit
import Darwin

@main
private struct ProviderSearchOutsideClickMonitorTests {
    @MainActor
    static func main() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let searchView = NSView(frame: CGRect(x: 100, y: 20, width: 150, height: 28))
        window.contentView?.addSubview(searchView)

        var dismissalCount = 0
        let router = CCHProviderSearchOutsideClickRouter()
        router.monitoredView = searchView
        router.update(isFocused: true) {
            dismissalCount += 1
        }

        expectEqual(
            router.handleMouseDown(
                in: window,
                locationInWindow: CGPoint(x: 90, y: 30)
            ),
            true,
            "an outside window event should be handled"
        )
        expectEqual(dismissalCount, 1, "an outside event should dismiss search focus")

        expectEqual(
            router.handleMouseDown(
                in: window,
                locationInWindow: CGPoint(x: 125, y: 30)
            ),
            false,
            "an event inside the complete search control should pass through"
        )
        expectEqual(dismissalCount, 1, "an inside event should not dismiss focus")

        router.update(isFocused: false) {
            dismissalCount += 1
        }
        expectEqual(
            router.handleMouseDown(
                in: window,
                locationInWindow: CGPoint(x: 90, y: 30)
            ),
            false,
            "an unfocused search should ignore outside events"
        )
        expectEqual(dismissalCount, 1, "an unfocused search should remain unchanged")

        let otherWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        router.update(isFocused: true) {
            dismissalCount += 1
        }
        expectEqual(
            router.handleMouseDown(
                in: otherWindow,
                locationInWindow: CGPoint(x: 90, y: 30)
            ),
            false,
            "events from another window should be ignored"
        )
        expectEqual(dismissalCount, 1, "another window should not dismiss search focus")
    }

    private static func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
