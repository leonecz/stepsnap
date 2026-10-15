import AppKit
import StepSnapCore

/// Глобальный монитор кликов мышью.
///
/// События, адресованные самому StepSnap, в монитор не приходят — поэтому клики по
/// нашим панелям шагами не становятся по построению.
/// Универсальный доступ для мониторинга мыши не нужен.
final class ClickMonitor {
    private let targetWindowID: UInt32
    private let onClick: (CGPoint) -> Void
    private var monitor: Any?

    init(targetWindowID: UInt32, onClick: @escaping (CGPoint) -> Void) {
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
        let decision = ClickRouter.decide(
            clickPoint: point,
            windows: WindowEnumerator.allWindows(),
            targetWindowID: targetWindowID
        )

        if case .step(let clickPoint, _) = decision {
            onClick(clickPoint)
        }
    }

    deinit {
        stop()
    }
}
