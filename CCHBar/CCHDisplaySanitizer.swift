import Foundation

enum CCHDisplaySanitizer {
    static func backendError(_ value: String, fallback: String = "CCH 操作失败") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        let squashed = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !looksLikeHTML(squashed) else { return fallback }

        let redacted = squashed
            .replacingOccurrences(
                of: #"(/[A-Za-z0-9._~@:%+\-]+){2,}"#,
                with: "[path]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"[A-Za-z]:\\[A-Za-z0-9._~@:%+\\ -]+"#,
                with: "[path]",
                options: .regularExpression
            )

        let limit = 160
        if redacted.count <= limit {
            return redacted
        }
        return "\(redacted.prefix(limit))..."
    }

    private static func looksLikeHTML(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased.contains("<html")
            || lowercased.contains("<!doctype")
            || lowercased.contains("<body")
            || lowercased.contains("</")
    }
}
