import AppKit
import SwiftUI

@main
struct CCHBarApp: App {
    @NSApplicationDelegateAdaptor(CCHAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class CCHAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: CCHStatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = CCHStatusItemController()
    }
}
