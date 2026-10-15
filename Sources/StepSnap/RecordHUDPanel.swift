import AppKit
import SwiftUI

/// Панель записи: счётчик шагов, превью последнего снимка и «Стоп».
///
/// Неактивирующая и не забирающая фокус: клики по эмулятору во время записи должны
/// доходить до эмулятора, а не до нас. Клик по самой панели шагом не становится —
/// глобальный монитор не видит событий, адресованных этому приложению.
@MainActor
final class RecordHUDPanel {
    private var panel: NSPanel?

    func show(appState: AppState) {
        hide()

        let hosting = NSHostingView(rootView: HUDView(appState: appState))
        let panel = HUDWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.nonactivatingPanel, .hudWindow, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting

        positionInTopRightCorner(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// Подстраивает панель под изменившееся содержимое (появилось или исчезло поле названия),
    /// сохраняя её положение в правом верхнем углу.
    func resizeToFit() {
        guard let panel, let hosting = panel.contentView as? NSHostingView<HUDView> else { return }

        let oldFrame = panel.frame
        let contentSize = hosting.fittingSize
        let newSize = panel.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size

        panel.setFrame(
            NSRect(
                origin: NSPoint(x: oldFrame.maxX - newSize.width, y: oldFrame.maxY - newSize.height),
                size: newSize
            ),
            display: true
        )
    }

    private func positionInTopRightCorner(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }

        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(x: visible.maxX - size.width - 12, y: visible.maxY - size.height - 12)
        )
    }
}

/// Панель без заголовка по умолчанию не умеет становиться ключевой,
/// а нам нужно, чтобы в неё можно было печатать название шага.
private final class HUDWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}
