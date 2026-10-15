import CoreGraphics
import Foundation
import StepSnapCore

/// Подставной источник кадров: отдаёт заранее заданную картинку или ошибку,
/// считает вызовы и умеет притворяться медленным.
final class FakeFrameSource: FrameSource {
    private let image: CGImage?
    private let error: Error?
    private let delay: Duration?

    private(set) var captureCount = 0
    private(set) var capturedWindowIDs: [UInt32] = []

    init(image: CGImage? = nil, error: Error? = nil, delay: Duration? = nil) {
        self.image = image
        self.error = error
        self.delay = delay
    }

    func capture(windowID: UInt32) async throws -> CapturedFrame {
        captureCount += 1
        capturedWindowIDs.append(windowID)

        if let delay {
            try? await Task.sleep(for: delay)
        }
        if let error {
            throw error
        }
        guard let image else {
            throw CaptureError.captureFailed("нет картинки")
        }

        return CapturedFrame(image: image)
    }
}
