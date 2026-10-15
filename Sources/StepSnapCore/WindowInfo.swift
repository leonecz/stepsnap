import CoreGraphics
import Foundation

/// Описание окна системы, пригодного для съёмки.
public struct WindowInfo: Equatable, Sendable {
    /// `kCGWindowNumber` — им же ScreenCaptureKit адресует окно.
    public let id: UInt32
    public let ownerPID: pid_t
    public let ownerName: String
    public let title: String
    /// Границы в глобальных координатах Core Graphics (начало — левый верхний угол основного экрана).
    public let bounds: CGRect
    public let layer: Int

    public init(id: UInt32, ownerPID: pid_t, ownerName: String, title: String, bounds: CGRect, layer: Int) {
        self.id = id
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.title = title
        self.bounds = bounds
        self.layer = layer
    }

    public var label: String {
        if title.isEmpty { return ownerName }
        if ownerName.isEmpty { return title }
        return "\(ownerName) — \(title)"
    }

    /// Собирает окно из элемента `CGWindowListCopyWindowInfo`.
    public static func from(raw: [String: Any]) -> WindowInfo? {
        guard
            let number = raw[kCGWindowNumber as String] as? NSNumber,
            let pid = raw[kCGWindowOwnerPID as String] as? NSNumber,
            let rawBounds = raw[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: rawBounds as CFDictionary)
        else { return nil }

        return WindowInfo(
            id: number.uint32Value,
            ownerPID: pid.int32Value,
            ownerName: raw[kCGWindowOwnerName as String] as? String ?? "",
            title: raw[kCGWindowName as String] as? String ?? "",
            bounds: bounds,
            layer: (raw[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        )
    }
}

public enum WindowFilter {
    /// Меньшие окна — это служебные панели, а не то, что снимает тестировщик.
    public static let minimumSide: CGFloat = 200

    /// Оставляет только окна, которые имеет смысл предлагать к записи.
    /// Порядок входа сохраняется: он идёт от переднего окна к заднему.
    public static func capturable(_ all: [WindowInfo], ownPID: pid_t) -> [WindowInfo] {
        all.filter { window in
            window.layer == 0
                && window.ownerPID != ownPID
                && !window.ownerName.isEmpty
                && window.bounds.width >= minimumSide
                && window.bounds.height >= minimumSide
        }
    }
}
