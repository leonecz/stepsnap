import CoreGraphics
import Foundation

/// Что делать с произошедшим кликом.
public enum ClickDecision: Equatable, Sendable {
    case step(point: CGPoint, normalized: NormalizedPoint?)
    case ignore
}

public enum ClickRouter {
    /// Решает, наш ли это клик.
    ///
    /// `windows` — список от переднего окна к заднему, как его отдаёт система.
    /// Шагом становится только клик, который получило выбранное окно: если сверху лежит
    /// чужое окно или панель самого StepSnap, клик до цели не дошёл и шага не будет.
    public static func decide(
        clickPoint: CGPoint,
        windows: [WindowInfo],
        targetWindowID: UInt32
    ) -> ClickDecision {
        guard let topmost = windows.first(where: { $0.layer == 0 && $0.bounds.contains(clickPoint) }) else {
            return .ignore
        }
        guard topmost.id == targetWindowID else { return .ignore }

        return .step(
            point: clickPoint,
            normalized: NormalizedPoint.from(point: clickPoint, inWindowBounds: topmost.bounds)
        )
    }
}
