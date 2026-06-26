import Foundation

struct CCHProviderModelTestResult: Equatable {
    let success: Bool
    let status: String
    let message: String
    let latencyMs: Double?
    let ttfbMs: Double?
    let model: String
    let httpStatusCode: Int?
    let errorMessage: String
}

private enum CCHProviderModelTestParser {
    static let latencyKeys = [
        "latencyMs",
        "responseTime",
        "durationMs",
        "duration",
        "totalLatencyMs",
        "totalLatency",
        "totalMs",
        "elapsedMs"
    ]

    static let ttfbKeys = [
        "ttfbMs",
        "ttfb",
        "ttfb_ms",
        "firstByteLatencyMs",
        "firstByteLatency",
        "firstByteMs",
        "first_byte_ms",
        "timeToFirstByteMs",
        "timeToFirstByte",
        "time_to_first_byte_ms",
        "firstResponseByteMs"
    ]

    static let preferredNestedKeys = [
        "details",
        "validationDetails",
        "metrics",
        "timings",
        "latency",
        "latencies",
        "result",
        "data",
        "response"
    ]
}

func parseProviderModelTestResult(_ value: Any) -> CCHProviderModelTestResult {
    let dict = value as? [String: Any] ?? [:]
    let details = cchModelTestDictionary(cchModelTestValue(dict, key: "details"))
    let validation = cchModelTestDictionary(cchModelTestValue(dict, key: "validationDetails"))
    let success = cchModelTestBoolValue(cchModelTestValue(dict, key: "success"))
    let status = cchModelTestStringValue(cchModelTestValue(dict, key: "status"), fallback: success ? "green" : "red")
    let message = cchModelTestStringValue(cchModelTestValue(dict, key: "message"), fallback: success ? "模型测试成功" : "模型测试失败")
    let latencyMs = cchModelTestFirstDurationMs(in: dict, keys: CCHProviderModelTestParser.latencyKeys)
    let ttfbMs = cchModelTestFirstDurationMs(in: dict, keys: CCHProviderModelTestParser.ttfbKeys)
    let model = cchModelTestFirstStringValue(
        dict,
        keys: ["model"],
        fallback: cchModelTestFirstStringValue(details, keys: ["model"])
    )
    let httpStatusCode = cchModelTestFirstOptionalInt(dict, keys: ["httpStatusCode", "statusCode"])
        ?? cchModelTestFirstOptionalInt(validation, keys: ["httpStatusCode", "statusCode"])
    let errorMessage = cchModelTestFirstStringValue(
        dict,
        keys: ["errorMessage", "error"],
        fallback: cchModelTestFirstStringValue(details, keys: ["errorMessage", "error"])
    )

    return CCHProviderModelTestResult(
        success: success,
        status: status,
        message: message,
        latencyMs: latencyMs,
        ttfbMs: ttfbMs,
        model: model,
        httpStatusCode: httpStatusCode,
        errorMessage: errorMessage
    )
}

private func cchModelTestDictionary(_ value: Any?) -> [String: Any] {
    value as? [String: Any] ?? [:]
}

private func cchModelTestValue(_ row: [String: Any], key: String) -> Any? {
    if let value = row[key] { return value }
    return row.first { entry in
        entry.key.caseInsensitiveCompare(key) == .orderedSame
    }?.value
}

private func cchModelTestFirstStringValue(
    _ row: [String: Any],
    keys: [String],
    fallback: String = ""
) -> String {
    for key in keys {
        let value = cchModelTestStringValue(cchModelTestValue(row, key: key))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            return value
        }
    }
    return fallback
}

private func cchModelTestStringValue(_ value: Any?, fallback: String = "") -> String {
    switch value {
    case let s as String: return s
    case let n as NSNumber: return n.stringValue
    default: return fallback
    }
}

private func cchModelTestFirstOptionalInt(_ row: [String: Any], keys: [String]) -> Int? {
    for key in keys {
        if let value = cchModelTestOptionalInt(cchModelTestValue(row, key: key)) {
            return value
        }
    }
    return nil
}

private func cchModelTestOptionalInt(_ value: Any?) -> Int? {
    if value == nil || value is NSNull { return nil }
    switch value {
    case let n as Int: return n
    case let n as Int64: return Int(n)
    case let n as Double: return Int(n)
    case let n as NSNumber: return n.intValue
    case let s as String:
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed) else { return nil }
        return Int(value)
    default: return nil
    }
}

private func cchModelTestBoolValue(_ value: Any?, fallback: Bool = false) -> Bool {
    switch value {
    case let b as Bool: return b
    case let n as NSNumber: return n.boolValue
    case let s as String: return ["true", "1", "yes"].contains(s.lowercased())
    default: return fallback
    }
}

private func cchModelTestFirstDurationMs(in value: Any, keys: [String], depth: Int = 4) -> Double? {
    guard depth >= 0 else { return nil }

    if let row = value as? [String: Any] {
        if let direct = cchModelTestFirstOptionalDurationMs(row, keys: keys) {
            return direct
        }

        for key in CCHProviderModelTestParser.preferredNestedKeys {
            guard let nested = cchModelTestValue(row, key: key) else { continue }
            if let match = cchModelTestFirstDurationMs(in: nested, keys: keys, depth: depth - 1) {
                return match
            }
        }

        for nested in row.values {
            if let match = cchModelTestFirstDurationMs(in: nested, keys: keys, depth: depth - 1) {
                return match
            }
        }
    }

    if let values = value as? [Any] {
        for nested in values {
            if let match = cchModelTestFirstDurationMs(in: nested, keys: keys, depth: depth - 1) {
                return match
            }
        }
    }

    return nil
}

private func cchModelTestFirstOptionalDurationMs(_ row: [String: Any], keys: [String]) -> Double? {
    for key in keys {
        if let value = cchModelTestDurationMs(cchModelTestValue(row, key: key)) {
            return value
        }
    }
    return nil
}

private func cchModelTestDurationMs(_ value: Any?) -> Double? {
    if value == nil || value is NSNull { return nil }
    switch value {
    case let n as Double: return n
    case let n as Int: return Double(n)
    case let n as Int64: return Double(n)
    case let n as NSNumber: return n.doubleValue
    case let s as String:
        let compact = s
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ",", with: "")
        if compact.hasSuffix("ms") {
            let number = compact.dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(number)
        }
        if compact.hasSuffix("s") {
            let number = compact.dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(number).map { $0 * 1000 }
        }
        return Double(compact)
    default:
        return nil
    }
}
