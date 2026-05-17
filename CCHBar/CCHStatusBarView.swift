import AppKit
import QuartzCore

final class CCHStatusBarView: NSView {
    static let visibleProviderCharacters = 16

    enum Payload {
        case idle(text: String)
        case running(provider: String, detail: String, elapsed: String, isRetrying: Bool, sessionCount: Int)
    }

    var payload: Payload = .idle(text: "CCH $0.00")
    var onClick: (() -> Void)?
    private var runningPulsePhase: CGFloat = 0
    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = CACurrentMediaTime()
    private var wasRunning = false
    private var idleTransitionProgress: CGFloat = 1
    private let pulseDuration: CFTimeInterval = 1.15

    var preferredWidth: CGFloat {
        switch payload {
        case .idle(let text):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
            ]
            let textWidth = ceil((text as NSString).size(withAttributes: attrs).width)
            return max(76, textWidth + 24)
        case .running:
            return 164
        }
    }

    override var isFlipped: Bool { true }

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
        case .idle(let text):
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
                drawRunningRing(color: NSColor.systemBlue.withAlphaComponent(blueAlpha), center: NSPoint(x: 6, y: 11))
            }
            drawLogoTriangle(color: idleColor, center: NSPoint(x: 6, y: 11))
            drawText(
                text,
                at: NSPoint(x: 17, y: 4),
                font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                color: .labelColor
            )
        case .running(let provider, let detail, let elapsed, let isRetrying, let sessionCount):
            wasRunning = true
            idleTransitionProgress = 0
            startRunningAnimation()
            let accent = isRetrying ? NSColor.systemOrange : NSColor.systemBlue
            drawRunningIcon(color: accent, center: NSPoint(x: 6, y: 11))
            if sessionCount > 1 {
                drawMultiSessionBadge(count: sessionCount, color: accent, x: 5, y: 2)
            }
            drawText(
                fixedPrefix(provider, maxCharacters: Self.visibleProviderCharacters),
                at: NSPoint(x: 18, y: 1),
                font: NSFont.systemFont(ofSize: 8.5, weight: .semibold),
                color: .labelColor
            )
            drawText(
                elapsed,
                at: NSPoint(x: 123, y: 3),
                font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold),
                color: accent
            )
            drawText(
                detail,
                at: NSPoint(x: 18, y: 11),
                font: NSFont.monospacedSystemFont(ofSize: 8, weight: .medium),
                color: isRetrying ? accent : NSColor.labelColor.withAlphaComponent(0.68)
            )
        }
    }

    private func drawText(_ value: String, at point: NSPoint, font: NSFont, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        NSAttributedString(string: value, attributes: attributes).draw(at: point)
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
        let width: CGFloat = 10
        let height: CGFloat = 9
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

    private func drawMultiSessionBadge(count: Int, color: NSColor, x: CGFloat, y: CGFloat) {
        let text = min(count, 9).description as NSString
        let badgeRect = NSRect(x: x, y: y, width: 8, height: 8)
        NSColor.windowBackgroundColor.withAlphaComponent(0.92).setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        color.withAlphaComponent(0.92).setStroke()
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: 0.5, dy: 0.5)).stroke()
        text.draw(
            at: NSPoint(x: x + 2.2, y: y - 0.4),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 6, weight: .bold),
                .foregroundColor: color
            ]
        )
    }
}
