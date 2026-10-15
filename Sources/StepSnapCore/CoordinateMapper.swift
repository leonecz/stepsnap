import CoreGraphics

/// Согласование систем координат.
public enum CoordinateMapper {
    /// `NSEvent` считает координаты от левого нижнего угла основного экрана,
    /// Core Graphics и `CGWindowListCopyWindowInfo` — от левого верхнего.
    public static func coreGraphicsPoint(appKitPoint: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: appKitPoint.x, y: primaryScreenHeight - appKitPoint.y)
    }
}
