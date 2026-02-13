import SwiftUI
import AppKit

@main
struct WindowTilerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let windowManager = WindowManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions
        if !AccessibilityService.shared.checkPermissions() {
            AccessibilityService.shared.requestPermissions()
        }

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Window Tiler")
            button.action = #selector(togglePopover)
        }

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(windowManager: windowManager)
        )
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Refresh window list before showing
                windowManager.refreshWindows()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                // Make the popover the key window so it can receive focus
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
