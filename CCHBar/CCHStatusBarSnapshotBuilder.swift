import Foundation

struct CCHStatusBarSnapshotInput {
    let showsDetails: Bool
    let reducedMotion: Bool
    let idlePrimary: String
    let idleDetail: String
    let idleCacheState: CCHCacheVisibilityState
    let recentLogs: [CCHLogEntry]
    let runningLogs: [CCHLogEntry]
    let cacheStatusByLogId: [Int: CCHCacheStatusContext]
    let cacheAlertLogIds: Set<Int>
    let generatedAt: Date
}

enum CCHStatusBarSnapshotBuilder {
    static func makeSnapshot(_ input: CCHStatusBarSnapshotInput) -> CCHStatusBarSnapshot {
        CCHStatusBarSnapshot(
            showsDetails: input.showsDetails,
            reducedMotion: input.reducedMotion,
            idlePrimary: input.idlePrimary,
            idleDetail: input.idleDetail,
            idleCacheState: input.idleCacheState,
            runningItems: input.runningLogs.map { runningItem(from: $0, input: input) },
            hasRecentLogs: !input.recentLogs.isEmpty,
            generatedAt: input.generatedAt
        )
    }

    private static func runningItem(
        from log: CCHLogEntry,
        input: CCHStatusBarSnapshotInput
    ) -> CCHStatusRunningItem {
        let model = firstNonEmpty(log.model, log.originalModel, "model")
        return CCHStatusRunningItem(
            id: log.sessionId.isEmpty ? "log-\(log.id)" : log.sessionId,
            logId: log.id,
            providerName: firstNonEmpty(log.providerName, "Provider"),
            model: model,
            multiplier: log.costMultiplier,
            isFastTier: log.isFastTier,
            isRetrying: false,
            startedAt: parsedCCHDate(log.createdAt),
            cacheState: cacheStatus(for: log, input: input).state
        )
    }

    private static func cacheStatus(
        for log: CCHLogEntry,
        input: CCHStatusBarSnapshotInput
    ) -> CCHCacheStatusContext {
        if input.cacheAlertLogIds.contains(log.id) {
            return CCHCacheStatusContext(
                state: .rebuilding,
                createdTokens: log.cacheCreationTokens,
                readTokens: log.cacheReadTokens
            )
        }
        return input.cacheStatusByLogId[log.id] ?? CCHCacheStatusContext(
            state: .normal,
            createdTokens: log.cacheCreationTokens,
            readTokens: log.cacheReadTokens
        )
    }

    private static func firstNonEmpty(_ values: String?...) -> String {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return ""
    }
}
