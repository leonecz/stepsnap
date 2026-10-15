import CoreGraphics
import Foundation
import StepSnapCore

/// Окна системы.
enum WindowEnumerator {
    /// Все окна от переднего к заднему, без фильтрации.
    ///
    /// Нужны для попадания клика: список обязан содержать и наши собственные панели,
    /// и мелкие чужие окна — иначе клик по ним будет ошибочно приписан окну под ними.
    static func allWindows() -> [WindowInfo] {
        guard let rawList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return rawList.compactMap(WindowInfo.from(raw:))
    }

    /// Окна, которые имеет смысл предложить к записи.
    static func capturableWindows() -> [WindowInfo] {
        WindowFilter.capturable(allWindows(), ownPID: getpid())
    }
}
