import AppKit
import QuartzCore

final class CCHStatusBarView: NSView {
    static let visibleProviderCharacters = 16
    static let fixedWidth: CGFloat = 164

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
    private var runningPulsePhase: CGFloat = 0
    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = CACurrentMediaTime()
    private var wasRunning = false
    private var idleTransitionProgress: CGFloat = 1
    private let pulseDuration: CFTimeInterval = 1.15
    private let iconCenter = NSPoint(x: 8, y: 11)
    private let textLeading: CGFloat = 21
    private let primaryLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let elapsedLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    private let cacheIndicatorLayer = CALayer()

    var preferredWidth: CGFloat {
        Self.fixedWidth
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let width = bounds.width
        let contentWidth = max(0, width - 56)
        primaryLabel.frame = NSRect(x: textLeading, y: 0, width: min(98, contentWidth), height: 11)
        detailLabel.frame = NSRect(x: textLeading, y: 10, width: min(106, contentWidth + 8), height: 11)

        let elapsedWidth: CGFloat = 42
        let elapsedX = max(textLeading + 70, width - elapsedWidth - 6)
        elapsedLabel.frame = NSRect(x: elapsedX, y: 0.8, width: elapsedWidth, height: 14)
        elapsedLabel.alignment = .center

        badgeLabel.frame = NSRect(x: 6.8, y: 1.1, width: 8, height: 8)
        cacheIndicatorLayer.frame = CGRect(
            x: elapsedLabel.frame.midX - 7,
            y: elapsedLabel.frame.maxY + 0.8,
            width: 14,
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
        case .running(let provider, let detail, let elapsed, let isRetrying, let sessionCount, _):
            wasRunning = true
            idleTransitionProgress = 0
            startRunningAnimation()
            let accent = isRetrying ? NSColor.systemOrange : NSColor.systemBlue
            drawRunningIcon(color: accent, center: iconCenter)
            if sessionCount > 1 {
                drawMultiSessionBadge(color: accent, x: 7, y: 2)
            }
            _ = provider
            _ = detail
            _ = elapsed
        }
    }

    private func configureLabels() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        for label in [primaryLabel, detailLabel, elapsedLabel, badgeLabel] {
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.lineBreakMode = .byClipping
            label.maximumNumberOfLines = 1
            addSubview(label)
        }
        primaryLabel.frame = NSRect(x: textLeading, y: 0, width: 98, height: 11)
        detailLabel.frame = NSRect(x: textLeading, y: 10, width: 106, height: 11)
        elapsedLabel.frame = NSRect(x: 119, y: 1.2, width: 42, height: 14)
        elapsedLabel.alignment = .center
        badgeLabel.frame = NSRect(x: 6.6, y: 0.8, width: 8, height: 8)
        badgeLabel.alignment = .center
        cacheIndicatorLayer.cornerRadius = 1.5
        cacheIndicatorLayer.frame = CGRect(x: 133, y: 16.8, width: 14, height: 2)
        cacheIndicatorLayer.opacity = 0
        layer?.addSublayer(cacheIndicatorLayer)
    }

    private func updateLabels() {
        switch payload {
        case .idle(let primary, let detail, let cacheState):
            primaryLabel.stringValue = fixedPrefix(primary, maxCharacters: Self.visibleProviderCharacters)
            primaryLabel.font = NSFont.systemFont(ofSize: 8.8, weight: .semibold)
            primaryLabel.textColor = .labelColor
            primaryLabel.frame = NSRect(x: textLeading, y: 0, width: 98, height: 11)

            detailLabel.stringValue = detail
            detailLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)
            detailLabel.textColor = NSColor.labelColor.withAlphaComponent(0.58)
            detailLabel.frame = NSRect(x: textLeading, y: 10, width: 112, height: 11)

            elapsedLabel.isHidden = true
            badgeLabel.isHidden = true
            updateCacheIndicator(state: cacheState)
        case .running(let provider, let detail, let elapsed, let isRetrying, let sessionCount, let cacheState):
            let accent = isRetrying ? NSColor.systemOrange : NSColor.systemBlue
            primaryLabel.stringValue = fixedPrefix(provider, maxCharacters: Self.visibleProviderCharacters)
            primaryLabel.font = NSFont.systemFont(ofSize: 8.5, weight: .semibold)
            primaryLabel.textColor = .labelColor
            primaryLabel.frame = NSRect(x: textLeading, y: 0, width: 98, height: 11)

            detailLabel.stringValue = detail
            detailLabel.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)
            detailLabel.textColor = isRetrying ? accent : NSColor.labelColor.withAlphaComponent(0.68)
            detailLabel.frame = NSRect(x: textLeading, y: 10, width: 103, height: 11)

            elapsedLabel.stringValue = elapsed
            elapsedLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            elapsedLabel.textColor = accent
            elapsedLabel.isHidden = false

            badgeLabel.stringValue = min(sessionCount, 9).description
            badgeLabel.font = NSFont.monospacedSystemFont(ofSize: 6, weight: .bold)
            badgeLabel.textColor = accent
            badgeLabel.isHidden = sessionCount <= 1
            updateCacheIndicator(state: cacheState)
        }
    }

    private func updateCacheIndicator(state: CCHCacheVisibilityState) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        switch state {
        case .normal:
            cacheIndicatorLayer.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.72).cgColor
            cacheIndicatorLayer.opacity = 0.38
        case .rebuilding:
            cacheIndicatorLayer.backgroundColor = NSColor.systemRed.withAlphaComponent(0.95).cgColor
            cacheIndicatorLayer.opacity = 1
        }
        CATransaction.commit()
    }

    private func fixedPrefix(_ value: String, maxCharacters: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else {
            return trimmed
        }
        return String(trimmed.prefix(maxCharacters))
    }

    private func drawLogoTriangle(color: NSColor, center: NSPoint) {
        color.setFill()
        let width: CGFloat = 9
        let height: CGFloat = 8
        let x = center.x - width / 2
        let y = center.y - height * 2 / 3
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x + width / 2, y: y))
        path.line(to: NSPoint(x: x + width, y: y + height))
        path.line(to: NSPoint(x: x, y: y + height))
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

    private func drawMultiSessionBadge(color: NSColor, x: CGFloat, y: CGFloat) {
        let badgeRect = NSRect(x: x, y: y, width: 8, height: 8)
        NSColor.windowBackgroundColor.withAlphaComponent(0.92).setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        color.withAlphaComponent(0.92).setStroke()
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}
