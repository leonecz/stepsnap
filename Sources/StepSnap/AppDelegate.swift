import AppKit
import StepSnapCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popover = NSPopover()
    let settingsStore = SettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let icon = NSImage(systemSymbolName: "camera", accessibilityDescription: "StepSnap")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuContentView(store: settingsStore))
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
