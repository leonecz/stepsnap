import CoreGraphics
import Foundation

/// Сторож записи: решает, что целевого окна больше нет и запись пора прекращать.
public enum RecordingWatchdog {
    public static let notFoundLimit = 5

    /// Останавливаться нужно, если окна с таким номером нет в системном списке окон,
    /// либо если снимки подряд его не находят (окно успело закрыться между кликом и снимком).
    public static func shouldStop(
        windowID: UInt32,
        windows: [WindowInfo],
        consecutiveWindowNotFoundCount: Int
    ) -> Bool {
        if !windows.contains(where: { $0.id == windowID }) {
            return true
        }
        return consecutiveWindowNotFoundCount >= notFoundLimit
    }
}
