import AppKit
import SwiftUI

@MainActor
final class CCHProviderSearchOutsideClickRouter {
    weak var monitoredView: NSView?

    private var isFocused = false
    private var onOutsideClick: () -> Void = {}

    func update(isFocused: Bool, onOutsideClick: @escaping () -> Void) {
        self.isFocused = isFocused
        self.onOutsideClick = onOutsideClick
    }

    @discardableResult
    func handleMouseDown(in eventWindow: NSWindow?, locationInWindow: CGPoint) -> Bool {
        guard isFocused,
              let monitoredView,
              let window = monitoredView.window,
              eventWindow === window else { return false }

        let localLocation = monitoredView.convert(locationInWindow, from: nil)
        guard CCHProviderSearchFocusPolicy.shouldDismiss(
            isFocused: true,
            searchFrame: monitoredView.bounds,
            tapLocation: localLocation
        ) else { return false }

        onOutsideClick()
        window.makeFirstResponder(nil)
        return true
    }
}

struct CCHProviderSearchOutsideClickMonitor: NSViewRepresentable {
    let isFocused: Bool
    let onOutsideClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.startMonitoring(view)
        context.coordinator.router.update(
            isFocused: isFocused,
            onOutsideClick: onOutsideClick
        )
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.router.monitoredView = nsView
        context.coordinator.router.update(
            isFocused: isFocused,
            onOutsideClick: onOutsideClick
        )
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    @MainActor
    final class Coordinator {
        let router = CCHProviderSearchOutsideClickRouter()
        private var localMonitor: Any?

        func startMonitoring(_ view: NSView) {
            router.monitoredView = view
            guard localMonitor == nil else { return }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self else { return event }
                self.router.handleMouseDown(
                    in: event.window,
                    locationInWindow: event.locationInWindow
                )
                return event
            }
        }

        func stopMonitoring() {
            guard let localMonitor else { return }
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        deinit {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
            }
        }
    }
}
