import AppKit
import StepSnapCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popover = NSPopover()
    let settingsStore = SettingsStore()

    private lazy var appState = AppState(settingsStore: settingsStore)
    private let hud = RecordHUDPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateStatusIcon()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        popover.behavior = .transient
        let hosting = NSHostingController(
            rootView: MenuContentView(
                appState: appState,
                onRequestClose: { [weak self] in self?.closePopover() }
            )
        )
        // Без этого поповер не пересчитывает высоту при смене содержимого и обрезает список окон.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        appState.onPhaseChanged = { [weak self] phase in
            self?.handlePhaseChange(phase)
        }
        appState.onHUDNeedsResize = { [weak self] in
            self?.hud.resizeToFit()
        }
        appState.onPauseChanged = { [weak self] in
            self?.updateStatusIcon()
        }

        appState.scanForUnfinished()
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

    // MARK: - Реакция на фазы

    private func handlePhaseChange(_ phase: AppState.Phase) {
        switch phase {
        case .recording:
            // Поповер закрывается: открытый поверх эмулятора, он съел бы первый клик.
            closePopover()
            hud.show(appState: appState)
        case .finished:
            hud.hide()
            showPopover()
        case .idle, .naming, .pickingWindow:
            hud.hide()
        }

        updateStatusIcon()
    }

    /// Иконка в строке меню: запись, пауза, покой.
    private func updateStatusIcon() {
        let symbol: String
        if appState.isPaused {
            symbol = "pause.circle"
        } else if appState.phase == .recording {
            symbol = "camera.fill"
        } else {
            symbol = "camera"
        }

        let description = appState.isPaused ? "StepSnap: запись на паузе" : "StepSnap"
        let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        icon?.isTemplate = true
        statusItem.button?.image = icon
    }
}
