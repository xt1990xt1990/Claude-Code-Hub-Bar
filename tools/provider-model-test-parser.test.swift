import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}

private func expectEqual(_ actual: Double?, _ expected: Double, _ message: String) {
    guard let actual, abs(actual - expected) < 0.001 else {
        fail("\(message): expected \(expected), got \(String(describing: actual))")
    }
}

private func expectEqual(_ actual: String, _ expected: String, _ message: String) {
    guard actual == expected else {
        fail("\(message): expected \(expected), got \(actual)")
    }
}

private func expectNil(_ actual: Double?, _ message: String) {
    guard actual == nil else {
        fail("\(message): expected nil, got \(String(describing: actual))")
    }
}

private func expectNil(_ actual: Int?, _ message: String) {
    guard actual == nil else {
        fail("\(message): expected nil, got \(String(describing: actual))")
    }
}

@main
private struct ProviderModelTestParserTests {
    static func main() {
        let topLevel = parseProviderModelTestResult([
            "success": true,
            "status": "green",
            "message": "ok",
            "model": "gpt-5.5",
            "latencyMs": 1244,
            "ttfbMs": 704
        ])
        expectEqual(topLevel.ttfbMs, 704, "reads top-level ttfbMs")
        expectEqual(topLevel.latencyMs, 1244, "keeps total latency")
        expectEqual(topLevel.model, "gpt-5.5", "keeps model")

        let nested = parseProviderModelTestResult([
            "success": true,
            "status": "yellow",
            "details": [
                "responseTime": "1530",
                "metrics": [
                    "timeToFirstByteMs": "512"
                ],
                "model": "claude-sonnet-4"
            ]
        ])
        expectEqual(nested.ttfbMs, 512, "reads nested timeToFirstByteMs")
        expectEqual(nested.latencyMs, 1530, "reads nested total latency")
        expectEqual(nested.model, "claude-sonnet-4", "reads nested model")

        let firstTokenOnly = parseProviderModelTestResult([
            "success": true,
            "status": "green",
            "latencyMs": 900,
            "details": [
                "metrics": [
                    "firstTokenMs": 420
                ]
            ]
        ])
        expectNil(firstTokenOnly.ttfbMs, "does not treat first token timing as first byte")

        let invalidStatusCode = parseProviderModelTestResult([
            "success": false,
            "statusCode": "not-a-number"
        ])
        expectNil(invalidStatusCode.httpStatusCode, "keeps malformed status code nil")
    }
}
