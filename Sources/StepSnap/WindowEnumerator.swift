import CoreGraphics
import Foundation
import StepSnapCore

/// Окна системы, которые имеет смысл предложить к записи.
enum WindowEnumerator {
    static func capturableWindows() -> [WindowInfo] {
        guard let rawList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return WindowFilter.capturable(rawList.compactMap(WindowInfo.from(raw:)), ownPID: getpid())
    }
}
