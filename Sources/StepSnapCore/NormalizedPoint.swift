import CoreGraphics
import Foundation

/// Точка клика в долях рамки окна: 0 — левый/верхний край, 1 — правый/нижний.
///
/// Хранится в долях, а не в координатах экрана, чтобы отметка клика оставалась верной,
/// если окно за время записи переехало или изменило размер.
public struct NormalizedPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// `nil`, если рамка окна вырождена: делить на её размер нельзя.
    public static func from(point: CGPoint, inWindowBounds bounds: CGRect) -> NormalizedPoint? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        return NormalizedPoint(
            x: Double((point.x - bounds.minX) / bounds.width),
            y: Double((point.y - bounds.minY) / bounds.height)
        )
    }
}
