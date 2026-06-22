import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func expectEqual(_ actual: String, _ expected: String, _ message: String) {
    guard actual == expected else {
        fail("\(message): expected \(expected), got \(actual)")
    }
}

private func expectTrue(_ condition: Bool, _ message: String) {
    guard condition else { fail(message) }
}

@main
private struct DisplaySanitizerTests {
    static func main() {
        expectEqual(
            CCHDisplaySanitizer.backendError(" \n "),
            "CCH 操作失败",
            "blank backend messages should use fallback text"
        )
        expectEqual(
            CCHDisplaySanitizer.backendError("<html><body>502</body></html>"),
            "CCH 操作失败",
            "HTML backend messages should not be displayed directly"
        )
        expectEqual(
            CCHDisplaySanitizer.backendError("failed at /var/log/cch/server.log"),
            "failed at [path]",
            "absolute paths should be redacted"
        )

        let longMessage = String(repeating: "a", count: 180)
        let sanitized = CCHDisplaySanitizer.backendError(longMessage)
        expectTrue(sanitized.count == 163, "long backend messages should be truncated to 160 chars plus ellipsis")
        expectTrue(sanitized.hasSuffix("..."), "truncated backend messages should end with ellipsis")
    }
}
