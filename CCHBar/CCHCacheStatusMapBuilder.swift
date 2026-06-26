import Foundation

struct CCHLogCacheStatusSnapshot {
    let logs: [CCHLogEntry]
    let statusByLogId: [Int: CCHCacheStatusContext]
    let latestRebuildingLogId: Int?
}

enum CCHCacheStatusMapBuilder {
    static func makeSnapshot(
        recentLogs: [CCHLogEntry],
        logs: [CCHLogEntry],
        history: [CCHLogEntry]
    ) -> CCHLogCacheStatusSnapshot {
        let combined = uniqueLogs([recentLogs, logs, history])
        let statusMap = build(for: combined)
        return CCHLogCacheStatusSnapshot(
            logs: combined,
            statusByLogId: statusMap,
            latestRebuildingLogId: latestRebuildingLogId(in: combined, statusMap: statusMap)
        )
    }

    static func mergeHistory(
        incomingLogs: [CCHLogEntry],
        history: [CCHLogEntry],
        limit: Int
    ) -> [CCHLogEntry] {
        let merged = uniqueLogs([incomingLogs, history])
            .sorted(by: isNewerLog)
        return Array(merged.prefix(limit))
    }

    static func build(for logs: [CCHLogEntry]) -> [Int: CCHCacheStatusContext] {
        var result: [Int: CCHCacheStatusContext] = [:]
        result.reserveCapacity(logs.count)

        var successfulLogsBySession: [String: [CCHLogEntry]] = [:]
        successfulLogsBySession.reserveCapacity(logs.count)
        for log in logs where log.statusCode.map({ (200..<300).contains($0) }) ?? false {
            successfulLogsBySession[cacheSessionKey(log), default: []].append(log)
        }

        for group in successfulLogsBySession.values {
            let ordered = group.sorted(by: isOlderLog)
            var previous: CCHLogEntry?
            for log in ordered {
                let state = isLargeCacheDrop(log, previous: previous) ? CCHCacheVisibilityState.rebuilding : .normal
                result[log.id] = CCHCacheStatusContext(
                    state: state,
                    createdTokens: log.cacheCreationTokens,
                    readTokens: log.cacheReadTokens
                )
                if log.inputTokens > 0 || log.cacheReadTokens > 0 || log.totalTokens > 0 {
                    previous = log
                }
            }
        }
        for log in logs where result[log.id] == nil {
            result[log.id] = CCHCacheStatusContext(
                state: .normal,
                createdTokens: log.cacheCreationTokens,
                readTokens: log.cacheReadTokens
            )
        }
        return result
    }

    private static func uniqueLogs(_ groups: [[CCHLogEntry]]) -> [CCHLogEntry] {
        var seen = Set<Int>()
        var result: [CCHLogEntry] = []
        result.reserveCapacity(groups.reduce(0) { $0 + $1.count })

        for group in groups {
            for log in group where seen.insert(log.id).inserted {
                result.append(log)
            }
        }

        return result
    }

    private static func latestRebuildingLogId(
        in logs: [CCHLogEntry],
        statusMap: [Int: CCHCacheStatusContext]
    ) -> Int? {
        var latest: CCHLogEntry?
        for log in logs where statusMap[log.id]?.state == .rebuilding {
            if let current = latest {
                if isNewerLog(log, current) {
                    latest = log
                }
            } else {
                latest = log
            }
        }
        return latest?.id
    }

    private static func isLargeCacheDrop(_ log: CCHLogEntry, previous: CCHLogEntry?) -> Bool {
        guard
            let previous,
            log.inputTokens >= 20_000,
            log.cacheReadTokens <= max(2_500, log.inputTokens / 18),
            previous.cacheReadTokens >= 15_000,
            !isCompactCacheRequest(log)
        else { return false }

        let previousCachedContext = previous.inputTokens + previous.cacheReadTokens
        guard previousCachedContext >= 20_000 else { return false }
        let ratio = Double(log.inputTokens) / Double(previousCachedContext)
        return ratio >= 0.55 && ratio <= 1.55
    }

    private static func isCompactCacheRequest(_ log: CCHLogEntry) -> Bool {
        let modelText = "\(log.model) \(log.originalModel)".lowercased()
        if modelText.contains("compact") { return true }
        if log.messagesCount > 0, log.messagesCount < 12 { return true }
        return false
    }

    private static func cacheSessionKey(_ log: CCHLogEntry) -> String {
        log.sessionId.isEmpty ? "log-\(log.id)" : log.sessionId
    }

    private static func isOlderLog(_ lhs: CCHLogEntry, _ rhs: CCHLogEntry) -> Bool {
        if lhs.sessionId == rhs.sessionId, lhs.requestSequence != rhs.requestSequence {
            return lhs.requestSequence < rhs.requestSequence
        }
        guard
            let lhsDate = parsedCCHDate(lhs.createdAt),
            let rhsDate = parsedCCHDate(rhs.createdAt)
        else { return lhs.id < rhs.id }
        return lhsDate < rhsDate
    }

    private static func isNewerLog(_ lhs: CCHLogEntry, _ rhs: CCHLogEntry) -> Bool {
        guard
            let lhsDate = parsedCCHDate(lhs.createdAt),
            let rhsDate = parsedCCHDate(rhs.createdAt)
        else { return lhs.id > rhs.id }
        return lhsDate > rhsDate
    }
}
