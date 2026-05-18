import AppKit
import QuartzCore

final class CCHStatusBarView: NSView {
    static func fixedWidth(showDetails: Bool) -> CGFloat {
        showDetails ? 116 : 92
    }

    enum Payload {
        case idle(primary: String, detail: String, cacheState: CCHCacheVisibilityState)
        case running(provider: String, detail: String, elapsed: String, isRetrying: Bool, sessionCount: Int, cacheState: CCHCacheVisibilityState)
    }

    var payload: Payload = .idle(primary: "TTL $0.00", detail: "0 req", cacheState: .normal) {
        didSet {
            updateLabels()
            needsLayout = true
            needsDisplay = true
        }
    }
    var onClick: (() -> Void)?
    var showsDetails = true {
        didSet {
            updateLabels()
            needsLayout = true
            needsDisplay = true
        }
    }
    private var runningPulsePhase: CGFloat = 0
    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = CACurrentMediaTime()
    private var marqueeStartTime: CFTimeInterval = CACurrentMediaTime()
    private var marqueeText = ""
    private var shouldMarqueePrimaryText = false
    private var wasRunning = false
    private var idleTransitionProgress: CGFloat = 1
    private let pulseDuration: CFTimeInterval = 1.15
    private let marqueePauseDuration: CFTimeInterval = 1.2
    private let marqueeSpeed: CGFloat = 18
    private let iconCenter = NSPoint(x: 7.0, y: 11)
    private let textLeading: CGFloat = 18
    private let primaryClipView = NSView()
    private let primaryLabel = NSTextField(labelWithString: "")
    private let marqueeCloneLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private let elapsedLabel = NSTextField(labelWithString: "")
    private let cacheIndicatorLayer = CALayer()

    var preferredWidth: CGFloat {
        Self.fixedWidth(showDetails: showsDetails)
    }

    var visibleProviderCharacters: Int {
        let reserve: CGFloat = showsDetails ? 48 : 10
        let textWidth = max(34, preferredWidth - reserve)
        return min(22, max(8, Int(textWidth / 6.3)))
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let width = bounds.width
        let isRunning: Bool
        let sessionCount: Int
        switch payload {
        case .idle:
            isRunning = false
            sessionCount = 0
        case .running(_, _, _, _, let count, _):
            isRunning = true
            sessionCount = count
        }

        let shouldShowElapsed = isRunning && showsDetails
        let shouldShowCount = isRunning && sessionCount > 1
        let elapsedWidth: CGFloat = shouldShowElapsed ? 27 : 0
        let countWidth: CGFloat = shouldShowCount ? 17 : 0
        let rightPadding: CGFloat = showsDetails ? 0 : 1
        let rightReserve = elapsedWidth + countWidth + (shouldShowElapsed && shouldShowCount ? 2 : 0) + rightPadding
        let textWidth = max(34, width - textLeading - rightReserve)

        primaryClipView.frame = NSRect(x: textLeading, y: 0, width: textWidth, height: 11)
        layoutPrimaryText(textWidth: textWidth)
        detailLabel.frame = NSRect(x: textLeading, y: 10, width: textWidth, height: 11)

        let elapsedX = width - elapsedWidth - rightPadding
        elapsedLabel.frame = NSRect(x: elapsedX, y: 0.8, width: elapsedWidth, height: 14)
        elapsedLabel.alignment = .center

        let countX = shouldShowElapsed ? elapsedX - countWidth - 2 : width - countWidth - rightPadding
        countLabel.frame = NSRect(x: countX, y: 1.0, width: countWidth, height: 13)
        countLabel.alignment = .right

        let detailCenterX = shouldShowElapsed ? elapsedLabel.frame.midX : width - rightPadding - 14
        cacheIndicatorLayer.frame = CGRect(
            x: detailCenterX - 6,
            y: 17.0,
            width: 12,
            height: 2
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLabels()
        updateLabels()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabels()
        updateLabels()
    }

    deinit {
        stopRunningAnimation()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        switch payload {
        case .idle(_, _, _):
            if wasRunning || idleTransitionProgress < 1 {
                beginIdleTransition()
            }
            let blueAlpha = max(0, 1 - idleTransitionProgress)
            let idleColor = blendColor(
                from: NSColor.systemBlue.withAlphaComponent(0.95),
                to: NSColor.labelColor.withAlphaComponent(0.56),
                progress: idleTransitionProgress
            )
            if blueAlpha > 0.02 {
                drawRunningRing(color: NSColor.systemBlue.withAlphaComponent(blueAlpha), center: iconCenter)
            }
            drawLogoTriangle(color: idleColor, center: iconCenter)
        case .running(let provider, let detail, let elapsed, let isRetrying, _, _):
            wasRunning = true
            idleTransitionProgress = 0
            startRunningAnimation()
            let accent = isRetrying ? NSColor.systemOrange : NSColor.systemBlue
            drawRunningIcon(color: accent, center: iconCenter)
            _ = provider
            _ = detail
            _ = elapsed
        }
    }

    private func configureLabels() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        primaryClipView.wantsLayer = true
        primaryClipView.layer?.backgroundColor = NSColor.clear.cgColor
        primaryClipView.layer?.masksToBounds = true
        addSubview(primaryClipView)

        for label in [primaryLabel, marqueeCloneLabel, detailLabel, countLabel, elapsedLabel] {
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.lineBreakMode = .byClipping
            label.maximumNumberOfLines = 1
        }
        primaryClipView.addSubview(primaryLabel)
        primaryClipView.addSubview(marqueeCloneLabel)
        for label in [detailLabel, countLabel, elapsedLabel] {
            addSubview(label)
        }
        primaryClipView.frame = NSRect(x: textLeading, y: 0, width: 98, height: 11)
        primaryLabel.frame = NSRect(x: 0, y: 0, width: 98, height: 11)
        marqueeCloneLabel.frame = NSRect(x: 0, y: 0, width: 98, height: 11)
        marqueeCloneLabel.isHidden = true
        detailLabel.frame = NSRect(x: textLeading, y: 10, width: 106, height: 11)
        countLabel.frame = NSRect(x: 104, y: 1.0, width: 18, height: 13)
        elapsedLabel.frame = NSRect(x: 119, y: 1.2, width: 42, height: 14)
        elapsedLabel.alignment = .center
        cacheIndicatorLayer.cornerRadius = 1.5
        cacheIndicatorLayer.frame = CGRect(x: 133, y: 16.8, width: 14, height: 2)
        cacheIndicatorLayer.opacity = 0
        layer?.addSublayer(cacheIndicatorLayer)
    }

    private func updateLabels() {
        switch payload {
        case .idle(let primary, let detail, let cacheState):
            setPrimaryText(primary, shouldMarquee: false)
            primaryLabel.font = NSFont.systemFont(ofSize: 8.8, weight: .semibold)
            primaryLabel.textColor = .labelColor
            marqueeCloneLabel.font = primaryLabel.font
            marqueeCloneLabel.textColor = primaryLabel.textColor
            marqueeCloneLabel.isHidden = true

            detailLabel.stringValue = detail
            detailLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)
            detailLabel.textColor = NSColor.labelColor.withAlphaComponent(0.58)

            countLabel.isHidden = true
            elapsedLabel.isHidden = true
            updateCacheIndicator(state: cacheState, isRunning: false)
        case .running(let provider, let detail, let elapsed, let isRetrying, let sessionCount, let cacheState):
            let accent = isRetrying ? NSColor.systemOrange : NSColor.systemBlue
            setPrimaryText(provider, shouldMarquee: true)
            primaryLabel.font = NSFont.systemFont(ofSize: 8.5, weight: .semibold)
            primaryLabel.textColor = .labelColor
            marqueeCloneLabel.font = primaryLabel.font
            marqueeCloneLabel.textColor = primaryLabel.textColor

            detailLabel.stringValue = detail
            detailLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)
            detailLabel.textColor = isRetrying ? accent : NSColor.labelColor.withAlphaComponent(0.68)

            elapsedLabel.stringValue = elapsed
            elapsedLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            elapsedLabel.textColor = accent
            elapsedLabel.isHidden = !showsDetails

            countLabel.stringValue = "×\(sessionCount)"
            countLabel.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .bold)
            countLabel.textColor = accent
            countLabel.isHidden = sessionCount <= 1

            updateCacheIndicator(state: cacheState, isRunning: true)
        }
    }

    private func setPrimaryText(_ value: String, shouldMarquee: Bool) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextText = trimmed.isEmpty ? "Provider" : trimmed
        if marqueeText != nextText {
            marqueeText = nextText
            marqueeStartTime = CACurrentMediaTime()
        }
        primaryLabel.stringValue = nextText
        marqueeCloneLabel.stringValue = nextText
        shouldMarqueePrimaryText = shouldMarquee
        marqueeCloneLabel.isHidden = true
        needsLayout = true
    }

    private func layoutPrimaryText(textWidth: CGFloat) {
        let primarySize = primaryLabel.intrinsicContentSize.width
        let shouldMarquee = shouldMarqueePrimaryText && primarySize > textWidth + 2
        guard shouldMarquee else {
            primaryLabel.frame = NSRect(x: 0, y: 0, width: textWidth, height: 11)
            marqueeCloneLabel.isHidden = true
            return
        }

        marqueeCloneLabel.isHidden = true
        let textRunWidth = ceil(primarySize)
        let offset = currentMarqueeOffset(textWidth: textWidth, textRunWidth: textRunWidth)
        primaryLabel.frame = NSRect(x: -offset, y: 0, width: textRunWidth, height: 11)
    }

    private func currentMarqueeOffset(textWidth: CGFloat, textRunWidth: CGFloat) -> CGFloat {
        let overflow = max(0, textRunWidth - textWidth)
        guard overflow > 1 else { return 0 }
        let movingDuration = CFTimeInterval(overflow / marqueeSpeed)
        let cycleDuration = marqueePauseDuration + movingDuration + marqueePauseDuration + movingDuration
        let elapsed = (CACurrentMediaTime() - marqueeStartTime).truncatingRemainder(dividingBy: cycleDuration)
        if elapsed < marqueePauseDuration {
            return 0
        }
        let forwardElapsed = elapsed - marqueePauseDuration
        if forwardElapsed < movingDuration {
            return easedMarqueeOffset(progress: forwardElapsed / movingDuration, overflow: overflow)
        }
        let tailPauseElapsed = forwardElapsed - movingDuration
        if tailPauseElapsed < marqueePauseDuration {
            return overflow
        }
        let backwardElapsed = min(movingDuration, tailPauseElapsed - marqueePauseDuration)
        return overflow - easedMarqueeOffset(progress: backwardElapsed / movingDuration, overflow: overflow)
    }

    private func easedMarqueeOffset(progress: CFTimeInterval, overflow: CGFloat) -> CGFloat {
        let clamped = CGFloat(min(1, max(0, progress)))
        let eased = clamped * clamped * (3 - 2 * clamped)
        return overflow * eased
    }

    private func updateCacheIndicator(state: CCHCacheVisibilityState, isRunning: Bool) {
        guard showsDetails else {
            cacheIndicatorLayer.opacity = 0
            return
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        switch state {
        case .normal:
            let color = isRunning
                ? NSColor.systemGreen.withAlphaComponent(0.82)
                : NSColor.labelColor.withAlphaComponent(0.30)
            cacheIndicatorLayer.backgroundColor = color.cgColor
            cacheIndicatorLayer.opacity = 0.82
        case .rebuilding:
            cacheIndicatorLayer.backgroundColor = NSColor.systemRed.withAlphaComponent(0.95).cgColor
            cacheIndicatorLayer.opacity = 1
        }
        CATransaction.commit()
    }

    private func drawLogoTriangle(color: NSColor, center: NSPoint) {
        color.setFill()
        let width: CGFloat = 7.8
        let height: CGFloat = 7.1
        let tipX = round(center.x * 2) / 2
        let tipY = round((center.y - height * 2 / 3) * 2) / 2
        let baseY = tipY + height
        let halfWidth = width / 2
        let path = NSBezierPath()
        path.move(to: NSPoint(x: tipX, y: tipY))
        path.line(to: NSPoint(x: tipX + halfWidth, y: baseY))
        path.line(to: NSPoint(x: tipX - halfWidth, y: baseY))
        path.close()
        path.fill()
    }

    private func drawRunningIcon(color: NSColor, center: NSPoint) {
        drawRunningRing(color: color, center: center)
        drawLogoTriangle(color: color, center: center)
    }

    private func drawRunningRing(color: NSColor, center: NSPoint) {
        let easedPhase = 1 - pow(1 - runningPulsePhase, 1.8)
        let size = 10 + easedPhase * 13
        let alpha = max(0, color.alphaComponent * 0.58 * (1 - runningPulsePhase))
        let ringRect = NSRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        color.withAlphaComponent(alpha).setStroke()
        let ring = NSBezierPath(ovalIn: ringRect)
        ring.lineWidth = 1.4
        ring.stroke()
    }

    private func startRunningAnimation() {
        guard animationTimer == nil else { return }
        animationStartTime = CACurrentMediaTime() - CFTimeInterval(runningPulsePhase) * pulseDuration
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = CACurrentMediaTime() - self.animationStartTime
            self.runningPulsePhase = CGFloat(elapsed.truncatingRemainder(dividingBy: self.pulseDuration) / self.pulseDuration)
            self.needsLayout = true
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func stopRunningAnimation() {
        guard let animationTimer else { return }
        animationTimer.invalidate()
        self.animationTimer = nil
        runningPulsePhase = 0
    }

    private func beginIdleTransition() {
        wasRunning = false
        if idleTransitionProgress >= 1 {
            stopRunningAnimation()
            return
        }
        startRunningAnimation()
        idleTransitionProgress = min(1, idleTransitionProgress + 0.08)
        if idleTransitionProgress >= 1 {
            stopRunningAnimation()
        }
    }

    private func blendColor(from: NSColor, to: NSColor, progress: CGFloat) -> NSColor {
        let from = from.usingColorSpace(.deviceRGB) ?? from
        let to = to.usingColorSpace(.deviceRGB) ?? to
        let p = min(1, max(0, progress))
        return NSColor(
            red: from.redComponent + (to.redComponent - from.redComponent) * p,
            green: from.greenComponent + (to.greenComponent - from.greenComponent) * p,
            blue: from.blueComponent + (to.blueComponent - from.blueComponent) * p,
            alpha: from.alphaComponent + (to.alphaComponent - from.alphaComponent) * p
        )
    }
}
