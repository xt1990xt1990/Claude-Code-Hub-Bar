import Foundation

struct CCHActiveSessionMenuSnapshot {
    let filteredSessions: [CCHActiveSession]
    let menuBarSessions: [CCHActiveSession]
    let currentMenuBarSession: CCHActiveSession?
}

enum CCHActiveSessionMenuBuilder {
    static func makeSnapshot(
        from activeSessions: [CCHActiveSession],
        userFilter: String
    ) -> CCHActiveSessionMenuSnapshot {
        let filtered = filteredSessions(from: activeSessions, userFilter: userFilter)
        let menuBar = filtered.filter { session in
            session.concurrentCount > 0
                || session.durationMs <= 0
                || isRunningStatus(session.status)
        }
        let current = menuBar
            .sorted { lhs, rhs in
                let lhsScore = activityScore(lhs)
                let rhsScore = activityScore(rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.startTime > rhs.startTime
            }
            .first

        return CCHActiveSessionMenuSnapshot(
            filteredSessions: filtered,
            menuBarSessions: menuBar,
            currentMenuBarSession: current
        )
    }

    static func filteredSessions(
        from activeSessions: [CCHActiveSession],
        userFilter: String
    ) -> [CCHActiveSession] {
        let ordered = activeSessions.sorted { $0.startTime > $1.startTime }
        let filter = userFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !filter.isEmpty else { return ordered }
        return ordered.filter { $0.userName.lowercased().contains(filter) }
    }

    static func menuBarSessions(
        from activeSessions: [CCHActiveSession],
        userFilter: String
    ) -> [CCHActiveSession] {
        makeSnapshot(from: activeSessions, userFilter: userFilter).menuBarSessions
    }

    static func currentMenuBarSession(
        from activeSessions: [CCHActiveSession],
        userFilter: String
    ) -> CCHActiveSession? {
        makeSnapshot(from: activeSessions, userFilter: userFilter).currentMenuBarSession
    }

    private static func isRunningStatus(_ status: String) -> Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return false }
        return normalized.contains("active")
            || normalized.contains("running")
            || normalized.contains("progress")
            || normalized.contains("request")
            || normalized.contains("retry")
            || normalized.contains("请求")
    }

    private static func activityScore(_ session: CCHActiveSession) -> Int {
        if session.concurrentCount > 0 { return 300 }
        if session.status.lowercased().contains("retry") { return 200 }
        if isRunningStatus(session.status) { return 100 }
        return 0
    }
}
