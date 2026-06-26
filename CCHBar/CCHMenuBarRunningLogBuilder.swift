import Foundation

enum CCHMenuBarRunningLogBuilder {
    static func runningLogs(from recentLogs: [CCHLogEntry]) -> [CCHLogEntry] {
        let ordered = recentLogs.sorted { lhs, rhs in
            if lhs.id != rhs.id { return lhs.id > rhs.id }
            if lhs.requestSequence != rhs.requestSequence {
                return lhs.requestSequence > rhs.requestSequence
            }
            return (parsedCCHDate(lhs.createdAt) ?? .distantPast) > (parsedCCHDate(rhs.createdAt) ?? .distantPast)
        }

        var seenSessionIds = Set<String>()
        return ordered.compactMap { log in
            guard log.statusCode == nil else { return nil }
            let key = log.sessionId.isEmpty ? "log-\(log.id)" : log.sessionId
            guard seenSessionIds.insert(key).inserted else { return nil }
            return log
        }
    }
}
