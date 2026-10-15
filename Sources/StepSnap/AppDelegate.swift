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
        popover.contentViewController = NSHostingController(
            rootView: MenuContentView(
                store: settingsStore,
                onPickWindow: { [weak self] window in
                    self?.startTemporaryClickProbe(for: window)
                },
                onRequestClose: { [weak self] in self?.closePopover() }
            )
        )
    }

    // ВРЕМЕННО, до Task 9: проверка, что клики в выбранном окне доходят до монитора.
    // Счётчик в строке меню показывает, сколько кликов признано нашими.
    private var probeMonitor: ClickMonitor?
    private var probeClickCount = 0

    private func startTemporaryClickProbe(for window: WindowInfo) {
        probeMonitor?.stop()
        probeClickCount = 0
        statusItem.button?.title = " 0"

        let monitor = ClickMonitor(targetWindowID: window.id) { [weak self] point in
            guard let self else { return }
            self.probeClickCount += 1
            self.statusItem.button?.title = " \(self.probeClickCount)"
            NSLog("StepSnap probe: шаг №%d в точке %@", self.probeClickCount, NSStringFromPoint(point))
        }
        monitor.start()
        probeMonitor = monitor

        NSLog("StepSnap probe: монитор запущен на окне %@ (%u)", window.label, window.id)
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
