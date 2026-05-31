import AppKit
import QuartzCore

final class CCHStatusBarView: NSView {
    private enum Metrics {
        static let collapsedWidth: CGFloat = 92
        static let expandedWidth: CGFloat = 116
    }

    static func fixedWidth(showDetails: Bool) -> CGFloat {
        showDetails ? Metrics.expandedWidth : Metrics.collapsedWidth
    }

    enum Payload: Equatable {
        case idle(primary: String, detail: String, cacheState: CCHCacheVisibilityState)
        case running(provider: String, detail: String, elapsed: String, isRetrying: Bool, sessionCount: Int, cacheState: CCHCacheVisibilityState)
    }

    var payload: Payload = .idle(primary: "TTL $0.00", detail: "0 req", cacheState: .normal) {
        didSet {
            guard payload != oldValue else { return }
            updateLabels()
            needsLayout = true
            needsDisplay = true
        }
    }
    var onClick: (() -> Void)?
    var showsDetails = true {
        didSet {
            guard showsDetails != oldValue else { return }
            updateLabels()
            needsLayout = true
            needsDisplay = true
        }
    }
    private var marqueeStartTime: CFTimeInterval = CACurrentMediaTime()
    private var marqueeText = ""
    private var shouldMarqueePrimaryText = false
    private var wasRunning = false
    private var idleTransitionProgress: CGFloat = 1
    private let pulseDuration: CFTimeInterval = 1.15
    private let marqueePauseDuration: CFTimeInterval = 1.2
    private let marqueeSpeed: CGFloat = 18
    private let animationFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    private let iconCenter = NSPoint(x: 7.0, y: 11)
    private let textLeading: CGFloat = 18
    private let primaryClipView = NSView()
    private let primaryLabel = NSTextField(labelWithString: "")
    private let marqueeCloneLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private let elapsedLabel = NSTextField(labelWithString: "")
    private let runningRingLayer = CAShapeLayer()
    private let cacheIndicatorLayer = CALayer()
    private var lastCacheIndicatorConfiguration: (state: CCHCacheVisibilityState, isRunning: Bool, showsDetails: Bool)?
    private var lastMarqueeConfiguration: (text: String, textWidth: CGFloat, textRunWidth: CGFloat)?

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
        updateRunningRingPath()
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
            let idleColor = blendColor(
                from: NSColor.systemBlue.withAlphaComponent(0.95),
                to: NSColor.labelColor.withAlphaComponent(0.56),
                progress: idleTransitionProgress
            )
            drawLogoTriangle(color: idleColor, center: iconCenter)
        case .running(let provider, let detail, let elapsed, let isRetrying, _, _):
            wasRunning = true
            idleTransitionProgress = 0
            let accent = isRetrying ? NSColor.systemOrange : NSColor.systemBlue
            startRunningAnimation(color: accent)
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
            label.wantsLayer = true
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
        runningRingLayer.fillColor = NSColor.clear.cgColor
        runningRingLayer.lineWidth = 1.8
        runningRingLayer.lineCap = .round
        runningRingLayer.opacity = 0
        layer?.addSublayer(runningRingLayer)
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
            lastMarqueeConfiguration = nil
            primaryLabel.layer?.removeAnimation(forKey: "marquee")
            primaryLabel.frame.origin.x = 0
            primaryLabel.layer?.transform = CATransform3DIdentity
        }
        primaryLabel.stringValue = nextText
        marqueeCloneLabel.stringValue = nextText
        if shouldMarqueePrimaryText != shouldMarquee {
            shouldMarqueePrimaryText = shouldMarquee
            lastMarqueeConfiguration = nil
        }
        marqueeCloneLabel.isHidden = true
        needsLayout = true
    }

    private func layoutPrimaryText(textWidth: CGFloat) {
        let primarySize = primaryLabel.intrinsicContentSize.width
        let shouldMarquee = shouldMarqueePrimaryText && primarySize > textWidth + 2
        guard shouldMarquee else {
            primaryLabel.layer?.removeAnimation(forKey: "marquee")
            lastMarqueeConfiguration = nil
            primaryLabel.frame = NSRect(x: 0, y: 0, width: textWidth, height: 11)
            marqueeCloneLabel.isHidden = true
            return
        }

        marqueeCloneLabel.isHidden = true
        let textRunWidth = ceil(primarySize)
        primaryLabel.frame = NSRect(x: 0, y: 0, width: textRunWidth, height: 11)
        let nextConfiguration = (text: marqueeText, textWidth: textWidth, textRunWidth: textRunWidth)
        if let lastMarqueeConfiguration,
           lastMarqueeConfiguration.text == nextConfiguration.text,
           abs(lastMarqueeConfiguration.textWidth - nextConfiguration.textWidth) < 0.5,
           abs(lastMarqueeConfiguration.textRunWidth - nextConfiguration.textRunWidth) < 0.5,
           primaryLabel.layer?.animation(forKey: "marquee") != nil {
            return
        }
        primaryLabel.layer?.removeAnimation(forKey: "marquee")
        lastMarqueeConfiguration = nextConfiguration
        applyMarqueeAnimation(textWidth: textWidth, textRunWidth: textRunWidth)
    }

    private func updateCacheIndicator(state: CCHCacheVisibilityState, isRunning: Bool) {
        let nextConfiguration = (state: state, isRunning: isRunning, showsDetails: showsDetails)
        if let lastCacheIndicatorConfiguration,
           lastCacheIndicatorConfiguration == nextConfiguration,
           cacheIndicatorLayer.animation(forKey: "breath") != nil || !isRunning {
            return
        }
        lastCacheIndicatorConfiguration = nextConfiguration

        guard showsDetails else {
            cacheIndicatorLayer.removeAnimation(forKey: "breath")
            cacheIndicatorLayer.opacity = 0
            return
        }
        switch state {
        case .normal:
            let target = isRunning
                ? NSColor.systemGreen.withAlphaComponent(0.95)
                : NSColor.labelColor.withAlphaComponent(0.30)
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.8)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            cacheIndicatorLayer.backgroundColor = target.cgColor
            CATransaction.commit()
            if isRunning {
                applyBreathingAnimation(period: 2.8, minOpacity: 0.45, maxOpacity: 1.0)
            } else {
                cacheIndicatorLayer.removeAnimation(forKey: "breath")
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.4)
                cacheIndicatorLayer.opacity = 0.55
                CATransaction.commit()
            }
        case .rebuilding:
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            cacheIndicatorLayer.backgroundColor = NSColor.systemRed.withAlphaComponent(0.95).cgColor
            CATransaction.commit()
            applyBreathingAnimation(period: 0.55, minOpacity: 0.55, maxOpacity: 1.0)
        }
    }

    private func applyBreathingAnimation(period: CFTimeInterval, minOpacity: Float, maxOpacity: Float) {
        if let animation = cacheIndicatorLayer.animation(forKey: "breath") as? CABasicAnimation,
           animation.duration == period / 2,
           cacheIndicatorLayer.opacity == maxOpacity {
            return
        }
        let presented = cacheIndicatorLayer.presentation()?.opacity ?? cacheIndicatorLayer.opacity
        cacheIndicatorLayer.removeAnimation(forKey: "breath")

        let breath = CABasicAnimation(keyPath: "opacity")
        breath.fromValue = minOpacity
        breath.toValue = maxOpacity
        breath.duration = period / 2
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        breath.timeOffset = breathPhaseOffset(currentOpacity: presented, minOpacity: minOpacity, maxOpacity: maxOpacity, halfPeriod: period / 2)
        cacheIndicatorLayer.add(breath, forKey: "breath")
        cacheIndicatorLayer.opacity = maxOpacity
    }

    private func breathPhaseOffset(currentOpacity: Float, minOpacity: Float, maxOpacity: Float, halfPeriod: CFTimeInterval) -> CFTimeInterval {
        let span = max(0.0001, maxOpacity - minOpacity)
        let normalized = max(0, min(1, (currentOpacity - minOpacity) / span))
        return CFTimeInterval(normalized) * halfPeriod
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
        drawLogoTriangle(color: color, center: center)
    }

    private func startRunningAnimation(color: NSColor = .systemBlue) {
        updateRunningRingPath()
        runningRingLayer.strokeColor = color.withAlphaComponent(0.92).cgColor
        if runningRingLayer.animation(forKey: "pulse") != nil {
            runningRingLayer.opacity = 1
            return
        }

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.45
        scale.toValue = 1.0
        scale.duration = pulseDuration
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.86
        opacity.toValue = 0
        opacity.duration = pulseDuration
        opacity.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = pulseDuration
        group.repeatCount = .infinity
        group.isRemovedOnCompletion = false
        group.preferredFrameRateRange = animationFrameRateRange
        runningRingLayer.add(group, forKey: "pulse")
        runningRingLayer.opacity = 1
    }

    private func stopRunningAnimation() {
        runningRingLayer.removeAnimation(forKey: "pulse")
        runningRingLayer.opacity = 0
    }

    private func updateRunningRingPath() {
        let size: CGFloat = 23
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        runningRingLayer.path = CGPath(ellipseIn: bounds.insetBy(dx: 0.9, dy: 0.9), transform: nil)
        runningRingLayer.bounds = bounds
        runningRingLayer.position = CGPoint(x: iconCenter.x, y: iconCenter.y)
        runningRingLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    private func applyMarqueeAnimation(textWidth: CGFloat, textRunWidth: CGFloat) {
        guard textRunWidth > textWidth + 2 else { return }
        let overflow = textRunWidth - textWidth
        let movingDuration = CFTimeInterval(overflow / marqueeSpeed)
        let cycleDuration = marqueePauseDuration + movingDuration + marqueePauseDuration + movingDuration
        let values: [CGFloat] = [0, 0, -overflow, -overflow, 0]
        let keyTimes: [NSNumber] = [
            0,
            NSNumber(value: marqueePauseDuration / cycleDuration),
            NSNumber(value: (marqueePauseDuration + movingDuration) / cycleDuration),
            NSNumber(value: (marqueePauseDuration + movingDuration + marqueePauseDuration) / cycleDuration),
            1
        ]

        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = values
        animation.keyTimes = keyTimes
        animation.duration = cycleDuration
        animation.repeatCount = .infinity
        animation.preferredFrameRateRange = animationFrameRateRange
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        primaryLabel.layer?.add(animation, forKey: "marquee")
    }

    private func beginIdleTransition() {
        wasRunning = false
        idleTransitionProgress = 1
        stopRunningAnimation()
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
