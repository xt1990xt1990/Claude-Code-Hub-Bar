import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class CCHStatusItemController: NSObject, NSPopoverDelegate {
    private enum PopoverFade {
        static let fadeInDuration: TimeInterval = 0.07
        static let fadeOutDuration: TimeInterval = 0.20
    }

    private let state = MonitorState()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusView = CCHStatusBarView(frame: NSRect(x: 0, y: 0, width: CCHStatusBarView.fixedWidth(showDetails: true), height: 22))
    private let popover = NSPopover()
    private var stateCancellable: AnyCancellable?
    private var rotationTimer: AnyCancellable?
    private var tickCounter = 0
    private var runningItemIndex = 0
    private var currentRunningItemId: String?
    private var lastRunningItems: [CCHStatusRunningItem] = []
    private var lastRunningItemIds: [String] = []
    private var lastRunningItemTotalCount = 0
    private var lastRunningItemsSeenAt: Date?
    private let maxRotatingRunningItems = 3
    private let runningSessionHoldDuration: TimeInterval = 5
    private var outsideClickMonitor: Any?
    private var lastAppliedSnapshot: CCHStatusBarSnapshot?
    private var lastPayload: CCHStatusBarView.Payload?
    private var lastTooltip: String?
    private var lastLength: CGFloat = 0
    private var isClosingPopover = false

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
        popover.behavior = .applicationDefined
        popover.delegate = self
        popover.animates = false
        popover.contentSize = NSSize(width: 760, height: 630)
    }

    private func ensurePopoverContentController() -> NSViewController {
        if let controller = popover.contentViewController {
            return controller
        }

        let host = NSHostingController(rootView: MenuBarView(state: state))
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        host.view.layer?.masksToBounds = false
        popover.contentViewController = host
        return host
    }

    private func observeState() {
        stateCancellable = state.$statusBarSnapshot
            .removeDuplicates()
            .sink { [weak self] snapshot in
                self?.applyStatusSnapshot(snapshot, force: false)
            }
        rotationTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.handleStatusTick()
            }
    }

    private func handleStatusTick() {
        tickCounter += 1
        let items = visibleMenuBarItems(from: state.statusBarSnapshot)
        if items.count > 1, tickCounter % 4 == 0 {
            advanceProviderRotation()
        } else {
            applyStatusSnapshot(state.statusBarSnapshot, force: true)
        }
    }

    private func updateStatusItem() {
        applyStatusSnapshot(state.statusBarSnapshot, force: true)
    }

    private func applyStatusSnapshot(_ snapshot: CCHStatusBarSnapshot, force: Bool) {
        let semanticSnapshotChanged = lastAppliedSnapshot != snapshot
        lastAppliedSnapshot = snapshot
        statusView.showsDetails = snapshot.showsDetails
        let items = visibleMenuBarItems(from: snapshot)
        let payload: CCHStatusBarView.Payload
        let tooltip: String
        if let item = visibleItem(from: items) {
            let provider = compactProviderName(item.providerName)
            let billing = item.model.trimmingCharacters(in: .whitespacesAndNewlines)
            let billingText = billing.isEmpty ? "model" : billing
            let totalCount = max(lastRunningItemTotalCount, items.count)
            let hiddenCount = max(0, totalCount - items.count)

            payload = .running(
                provider: provider,
                detail: "\(item.isRetrying ? "retrying " : "")\(billingText) \(formatMultiplier(item.multiplier))",
                elapsed: elapsedText(for: item),
                isRetrying: item.isRetrying,
                sessionCount: totalCount,
                cacheState: item.cacheState
            )
            tooltip = hiddenCount > 0
                ? "\(provider) · \(billingText) · \(formatMultiplier(item.multiplier)) · 另有 \(hiddenCount) 个运行中"
                : "\(provider) · \(billingText) · \(formatMultiplier(item.multiplier))"
            currentRunningItemId = item.id
        } else {
            runningItemIndex = 0
            currentRunningItemId = nil
            payload = .idle(
                primary: snapshot.idlePrimary,
                detail: snapshot.idleDetail,
                cacheState: snapshot.idleCacheState
            )
            tooltip = "Claude Code Hub idle"
        }

        if force || semanticSnapshotChanged || lastPayload != payload {
            statusView.payload = payload
            lastPayload = payload
        }
        if force || semanticSnapshotChanged || lastTooltip != tooltip {
            statusItem.button?.toolTip = tooltip
            lastTooltip = tooltip
        }
        let width = statusView.preferredWidth
        if force || abs(lastLength - width) > 0.5 {
            statusItem.length = width
            lastLength = width
        }
    }

    private func advanceProviderRotation() {
        let items = visibleMenuBarItems(from: state.statusBarSnapshot)
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

    private func visibleMenuBarItems(from snapshot: CCHStatusBarSnapshot) -> [CCHStatusRunningItem] {
        if !snapshot.runningItems.isEmpty {
            let items = Array(snapshot.runningItems.prefix(maxRotatingRunningItems))
            reconcileRunningItemIndex(for: items)
            lastRunningItems = items
            lastRunningItemIds = items.map(\.id)
            lastRunningItemTotalCount = snapshot.runningItems.count
            lastRunningItemsSeenAt = snapshot.generatedAt
            return items
        }

        guard
            !lastRunningItems.isEmpty,
            let seenAt = lastRunningItemsSeenAt,
            shouldHoldLastRunningSessions(since: seenAt)
        else {
            lastRunningItems = []
            lastRunningItemIds = []
            lastRunningItemTotalCount = 0
            lastRunningItemsSeenAt = nil
            runningItemIndex = 0
            currentRunningItemId = nil
            return []
        }

        if runningItemIndex >= lastRunningItems.count {
            runningItemIndex = 0
        }
        return lastRunningItems
    }

    private func reconcileRunningItemIndex(for items: [CCHStatusRunningItem]) {
        let ids = items.map(\.id)
        defer { lastRunningItemIds = ids }

        guard ids != lastRunningItemIds else {
            if runningItemIndex >= items.count {
                runningItemIndex = 0
            }
            return
        }

        if let currentRunningItemId,
           let stableIndex = items.firstIndex(where: { $0.id == currentRunningItemId }) {
            runningItemIndex = stableIndex
        } else if runningItemIndex >= items.count {
            runningItemIndex = 0
        }
    }

    private func shouldHoldLastRunningSessions(since seenAt: Date) -> Bool {
        let snapshot = state.statusBarSnapshot
        if snapshot.hasRecentLogs, snapshot.runningItems.isEmpty { return false }
        return Date().timeIntervalSince(seenAt) < runningSessionHoldDuration
    }

    private func visibleItem(from items: [CCHStatusRunningItem]) -> CCHStatusRunningItem? {
        guard !items.isEmpty else { return nil }
        return items[visibleItemIndex(for: items)]
    }

    private func visibleItemIndex(for items: [CCHStatusRunningItem]) -> Int {
        items.count > 1 ? runningItemIndex % items.count : 0
    }

    private func elapsedText(for item: CCHStatusRunningItem) -> String {
        guard let startedAt = item.startedAt else { return "--" }
        return formatDuration(Date().timeIntervalSince(startedAt))
    }

    @objc private func togglePopoverAction() {
        togglePopover()
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopoverLightly()
        } else {
            showPopoverLightly(relativeTo: button.bounds, of: button)
        }
    }

    private func showPopoverLightly(relativeTo rect: NSRect, of button: NSView) {
        isClosingPopover = false
        let contentController = ensurePopoverContentController()
        state.setPanelVisible(true)
        contentController.view.alphaValue = 0
        popover.show(relativeTo: rect, of: button, preferredEdge: .minY)

        guard let window = contentController.view.window else {
            contentController.view.alphaValue = 1
            startOutsideClickMonitor()
            return
        }
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.alphaValue = 0
        window.makeKey()
        contentController.view.alphaValue = 1

        forceActiveMaterial(in: contentController.view)
        startOutsideClickMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PopoverFade.fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    private func closePopoverLightly() {
        guard popover.isShown, !isClosingPopover else { return }
        isClosingPopover = true

        guard let window = popover.contentViewController?.view.window else {
            popover.performClose(nil)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PopoverFade.fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.popover.performClose(nil)
        }
    }

    private func forceActiveMaterial(in view: NSView) {
        if let effect = view as? NSVisualEffectView {
            effect.state = .active
        }
        for sub in view.subviews {
            forceActiveMaterial(in: sub)
        }
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            self.closePopoverLightly()
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        isClosingPopover = false
        popover.contentViewController?.view.window?.alphaValue = 1
        popover.contentViewController?.view.alphaValue = 1
        stopOutsideClickMonitor()
        state.setPanelVisible(false)
        popover.contentViewController = nil
    }
}
