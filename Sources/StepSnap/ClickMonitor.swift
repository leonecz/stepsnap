import AppKit
import StepSnapCore

/// Глобальный монитор кликов мышью.
///
/// События, адресованные самому StepSnap, в монитор не приходят — поэтому клики по
/// нашим панелям шагами не становятся по построению.
/// Универсальный доступ для мониторинга мыши не нужен.
final class ClickMonitor {
    private let targetWindowID: UInt32
    private let onClick: (CGPoint, CGRect) -> Void
    private var monitor: Any?

    init(targetWindowID: UInt32, onClick: @escaping (CGPoint, CGRect) -> Void) {
        self.targetWindowID = targetWindowID
        self.onClick = onClick
    }

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.handleClick()
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handleClick() {
        guard let primaryScreenHeight = NSScreen.screens.first?.frame.height else { return }

        let point = CoordinateMapper.coreGraphicsPoint(
            appKitPoint: NSEvent.mouseLocation,
            primaryScreenHeight: primaryScreenHeight
        )
        let windows = WindowEnumerator.allWindows()
        let decision = ClickRouter.decide(
            clickPoint: point,
            windows: windows,
            targetWindowID: targetWindowID
        )

        guard case .step(let clickPoint, _) = decision,
              let target = windows.first(where: { $0.id == targetWindowID })
        else { return }

        // Границы целевого окна берём из того же списка, по которому принимали решение:
        // сессия считает по ним относительную точку клика.
        onClick(clickPoint, target.bounds)
    }

    deinit {
        stop()
    }
}
