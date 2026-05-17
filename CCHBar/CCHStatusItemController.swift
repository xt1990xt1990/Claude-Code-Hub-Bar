import AppKit
import Combine
import SwiftUI

private struct CCHMenuBarRunningItem {
    let id: String
    let providerName: String
    let model: String
    let multiplier: Double
    let isRetrying: Bool
    let startedAt: Date?
}

@MainActor
final class CCHStatusItemController: NSObject, NSPopoverDelegate {
    private let state = MonitorState()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusView = CCHStatusBarView(frame: NSRect(x: 0, y: 0, width: 112, height: 22))
    private let popover = NSPopover()
    private var stateCancellable: AnyCancellable?
    private var rotationTimer: AnyCancellable?
    private var tickCounter = 0
    private var runningItemIndex = 0
    private var lastRunningItems: [CCHMenuBarRunningItem] = []
    private var lastRunningItemsSeenAt: Date?
    private let runningSessionHoldDuration: TimeInterval = 5

    override init() {
        super.init()
        configureStatusItem()
        configurePopover()
        observeState()
        updateStatusItem()
    }

    private func configureStatusItem() {
        statusView.onClick = { [weak self] in
            self?.togglePopover()
        }
        statusItem.length = statusView.preferredWidth

        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(togglePopoverAction)

        statusView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(statusView)
        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            statusView.topAnchor.constraint(equalTo: button.topAnchor),
            statusView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 760, height: 630)
        popover.contentViewController = NSHostingController(rootView: MenuBarView(state: state))
    }

    private func observeState() {
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        rotationTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.handleStatusTick()
            }
    }

    private func handleStatusTick() {
        tickCounter += 1
        let items = visibleMenuBarItems
        if items.count > 1, tickCounter % 2 == 0 {
            advanceProviderRotation()
        } else {
            updateStatusItem()
        }
    }

    private func updateStatusItem() {
        let items = visibleMenuBarItems
        if let item = visibleItem(from: items) {
            let provider = compactScrollingText(
                compactProviderName(item.providerName),
                offset: tickCounter,
                visibleCharacters: CCHStatusBarView.visibleProviderCharacters
            )
            let billing = item.model.trimmingCharacters(in: .whitespacesAndNewlines)
            let billingText = billing.isEmpty ? "model" : billing

            statusView.payload = .running(
                provider: provider,
                detail: "\(item.isRetrying ? "retrying " : "")\(billingText) \(formatMultiplier(item.multiplier))",
                elapsed: elapsedText(for: item),
                isRetrying: item.isRetrying,
                sessionCount: items.count
            )
            statusItem.button?.toolTip = "\(provider) · \(billingText) · \(formatMultiplier(item.multiplier))"
        } else {
            runningItemIndex = 0
            statusView.payload = .idle(text: state.menuBarText)
            statusItem.button?.toolTip = "Claude Code Hub idle"
        }

        statusItem.length = statusView.preferredWidth
        statusView.needsDisplay = true
    }

    private func advanceProviderRotation() {
        let items = visibleMenuBarItems
        guard !items.isEmpty else {
            updateStatusItem()
            return
        }

        guard items.count > 1 else {
            resetRunningIndexIfNeeded()
            return
        }

        runningItemIndex = (runningItemIndex + 1) % items.count
        updateStatusItem()
    }

    private func resetRunningIndexIfNeeded() {
        if runningItemIndex != 0 {
            runningItemIndex = 0
            updateStatusItem()
        }
    }

    private var visibleMenuBarItems: [CCHMenuBarRunningItem] {
        let items = currentMenuBarItems
        if !items.isEmpty {
            lastRunningItems = items
            lastRunningItemsSeenAt = Date()
            if runningItemIndex >= items.count {
                runningItemIndex = 0
            }
            return items
        }

        guard
            !lastRunningItems.isEmpty,
            let seenAt = lastRunningItemsSeenAt,
            shouldHoldLastRunningSessions(since: seenAt)
        else {
            lastRunningItems = []
            lastRunningItemsSeenAt = nil
            runningItemIndex = 0
            return []
        }

        if runningItemIndex >= lastRunningItems.count {
            runningItemIndex = 0
        }
        return lastRunningItems
    }

    private func shouldHoldLastRunningSessions(since seenAt: Date) -> Bool {
        if !state.recentLogs.isEmpty, state.menuBarRunningLogs.isEmpty { return false }
        return Date().timeIntervalSince(seenAt) < runningSessionHoldDuration
    }

    private var currentMenuBarItems: [CCHMenuBarRunningItem] {
        state.menuBarRunningLogs.map { menuBarItem(from: $0) }
    }

    private func visibleItem(from items: [CCHMenuBarRunningItem]) -> CCHMenuBarRunningItem? {
        guard !items.isEmpty else { return nil }
        return items[visibleItemIndex(for: items)]
    }

    private func visibleItemIndex(for items: [CCHMenuBarRunningItem]) -> Int {
        items.count > 1 ? runningItemIndex % items.count : 0
    }

    private func menuBarItem(from log: CCHLogEntry) -> CCHMenuBarRunningItem {
        let id = log.sessionId.isEmpty ? "log-\(log.id)" : log.sessionId
        let model = log.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? log.originalModel
            : log.model
        return CCHMenuBarRunningItem(
            id: id,
            providerName: log.providerName,
            model: model,
            multiplier: state.providerMultiplier(for: log.providerName),
            isRetrying: false,
            startedAt: parseCCHDate(log.createdAt)
        )
    }

    private func menuBarItem(from session: CCHActiveSession) -> CCHMenuBarRunningItem {
        let id = session.sessionId.isEmpty
            ? "\(session.providerId)-\(session.providerName)-\(session.startTime)"
            : session.sessionId
        let model = session.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? session.apiType
            : session.model
        return CCHMenuBarRunningItem(
            id: id,
            providerName: session.providerName,
            model: model,
            multiplier: state.providerMultiplierById[session.providerId] ?? state.providerMultiplier(for: session.providerName),
            isRetrying: session.status.lowercased().contains("retry"),
            startedAt: Date(timeIntervalSince1970: TimeInterval(session.startTime) / 1000)
        )
    }

    private func elapsedText(for item: CCHMenuBarRunningItem) -> String {
        guard let startedAt = item.startedAt else { return "--" }
        return formatDuration(Date().timeIntervalSince(startedAt))
    }

    private func coalescedCurrentSessions(from sessions: [CCHActiveSession]) -> [CCHActiveSession] {
        var bestBySession: [String: CCHActiveSession] = [:]

        for session in sessions {
            let key = session.sessionId.isEmpty
                ? "\(session.providerId)-\(session.providerName)-\(session.startTime)"
                : session.sessionId

            if let existing = bestBySession[key] {
                if isHigherPriority(session, than: existing) {
                    bestBySession[key] = session
                }
            } else {
                bestBySession[key] = session
            }
        }

        return bestBySession.values.sorted { lhs, rhs in
            isHigherPriority(lhs, than: rhs)
        }
    }

    private func isHigherPriority(_ lhs: CCHActiveSession, than rhs: CCHActiveSession) -> Bool {
        let lhsScore = priorityScore(lhs)
        let rhsScore = priorityScore(rhs)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore
        }
        if lhs.requestCount != rhs.requestCount {
            return lhs.requestCount > rhs.requestCount
        }
        if lhs.totalTokens != rhs.totalTokens {
            return lhs.totalTokens > rhs.totalTokens
        }
        return lhs.startTime > rhs.startTime
    }

    private func priorityScore(_ session: CCHActiveSession) -> Int {
        let normalizedStatus = session.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var score = 0
        if session.concurrentCount > 0 {
            score += 1_000 + min(session.concurrentCount, 50)
        }
        if normalizedStatus.contains("retry") {
            score += 200
        }
        if normalizedStatus.contains("active")
            || normalizedStatus.contains("running")
            || normalizedStatus.contains("progress")
            || normalizedStatus.contains("request")
            || normalizedStatus.contains("请求") {
            score += 100
        }
        return score
    }

    @objc private func togglePopoverAction() {
        togglePopover()
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            state.setPanelVisible(true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Task { await state.refreshFocusedView() }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        state.setPanelVisible(false)
    }
}
