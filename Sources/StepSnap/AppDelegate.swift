import AppKit
import ImageIO
import StepSnapCore
import SwiftUI
import UniformTypeIdentifiers

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
        let hosting = NSHostingController(
            rootView: MenuContentView(
                store: settingsStore,
                onPickWindow: { [weak self] window in
                    self?.startTemporaryClickProbe(for: window)
                },
                onRequestClose: { [weak self] in self?.closePopover() }
            )
        )
        // Без этого поповер не пересчитывает высоту при смене содержимого и обрезает список окон.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
    }

    // ВРЕМЕННО, до Task 9: проверка, что клики в выбранном окне доходят до монитора,
    // и что снимок окна получается. Счётчик кликов показывается в строке меню.
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

        takeTemporaryProbeScreenshot(of: window)
    }

    private var didRequestScreenRecordingPermission = false

    private func takeTemporaryProbeScreenshot(of window: WindowInfo) {
        if !Permissions.screenRecordingGranted() {
            if !didRequestScreenRecordingPermission {
                didRequestScreenRecordingPermission = true
                Permissions.requestScreenRecording()
            }
            statusItem.button?.title = " !"
            NSLog("StepSnap probe: нет разрешения на запись экрана. Выдайте разрешение и перезапустите приложение.")
            return
        }

        Task { @MainActor in
            do {
                let frame = try await ScreenCaptureFrameSource().capture(windowID: window.id)
                let folder = settingsStore.current.outputFolder
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appendingPathComponent("_probe.png")

                guard let destination = CGImageDestinationCreateWithURL(
                    url as CFURL,
                    UTType.png.identifier as CFString,
                    1,
                    nil
                ) else {
                    throw CaptureError.captureFailed("не удалось создать файл")
                }
                CGImageDestinationAddImage(destination, frame.image, nil)
                guard CGImageDestinationFinalize(destination) else {
                    throw CaptureError.captureFailed("не удалось записать файл")
                }

                NSLog("StepSnap probe: снимок %dx%d записан в %@", frame.pixelSize.width, frame.pixelSize.height, url.path)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                statusItem.button?.title = " !"
                NSLog("StepSnap probe: снимок не удался: %@", String(describing: error))
            }
        }
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
