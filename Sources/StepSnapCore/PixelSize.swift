import CoreGraphics
import Foundation

/// Размер кадра в пикселях.
public struct PixelSize: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Переводит прямоугольник в точках в пиксели с учётом масштаба экрана.
    /// Никогда не отдаёт ноль: ScreenCaptureKit не примет кадр нулевого размера.
    public static func fitting(rect: CGRect, scale: CGFloat) -> PixelSize {
        PixelSize(
            width: max(1, Int((rect.width * scale).rounded())),
            height: max(1, Int((rect.height * scale).rounded()))
        )
    }
}
