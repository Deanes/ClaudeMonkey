import SwiftUI
import Cocoa

@main
struct ClaudeMonkeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — menubar only
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var engine: MonkeyEngine!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        engine = MonkeyEngine()

        // Check accessibility on launch
        if !engine.checkAccessibility() {
            // Will prompt the user
        }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🐵"
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(engine: engine)
        )
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Rebuild the content view on each open so SwiftUI controls (the
            // Auto-Approve switch in particular) always render the engine's
            // current state instead of a stale cached appearance.
            popover.contentViewController = NSHostingController(
                rootView: MenuBarView(engine: engine)
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure popover gets focus
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
