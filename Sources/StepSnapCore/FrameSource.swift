import CoreGraphics
import Foundation

/// Кадр, снятый с окна.
public struct CapturedFrame {
    public let image: CGImage

    public init(image: CGImage) {
        self.image = image
    }

    public var pixelSize: PixelSize {
        PixelSize(width: image.width, height: image.height)
    }
}

/// Источник кадров. Реализация для ScreenCaptureKit — в приложении,
/// в тестах — подставной источник.
public protocol FrameSource: AnyObject {
    func capture(windowID: UInt32) async throws -> CapturedFrame
}

public enum CaptureError: Error, Equatable {
    case windowNotFound
    case permissionDenied
    case captureFailed(String)
}
