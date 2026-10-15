import AppKit
import CoreGraphics
import ScreenCaptureKit
import StepSnapCore

/// Снимок конкретного окна через ScreenCaptureKit.
///
/// `desktopIndependentWindow` даёт ровно то, что нужно: кадр только этого окна, а не всего
/// монитора, и кадр даже если окно частично перекрыто другим окном.
final class ScreenCaptureFrameSource: FrameSource {
    func capture(windowID: UInt32) async throws -> CapturedFrame {
        guard Permissions.screenRecordingGranted() else {
            throw CaptureError.permissionDenied
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }

        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        // Масштаб берём у самого фильтра: окно может висеть на втором мониторе,
        // и масштаб основного экрана к нему не относится.
        let scale = filter.pointPixelScale > 0
            ? CGFloat(filter.pointPixelScale)
            : (NSScreen.main?.backingScaleFactor ?? 2)
        let size = PixelSize.fitting(rect: filter.contentRect, scale: scale)

        let configuration = SCStreamConfiguration()
        configuration.width = size.width
        configuration.height = size.height
        configuration.showsCursor = false

        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            return CapturedFrame(image: image)
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }
}
