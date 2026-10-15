import CoreGraphics
import Testing
@testable import StepSnapCore

@Suite struct PixelSizeTests {
    @Test func pixelSizeScalesForRetina() {
        let size = PixelSize.fitting(rect: CGRect(x: 0, y: 0, width: 100, height: 200), scale: 2)

        #expect(size == PixelSize(width: 200, height: 400))
    }

    @Test func pixelSizeRoundsFractionalPoints() {
        let size = PixelSize.fitting(rect: CGRect(x: 0, y: 0, width: 100.4, height: 200.6), scale: 1)

        #expect(size == PixelSize(width: 100, height: 201))
    }

    @Test func pixelSizeNeverZero() {
        #expect(PixelSize.fitting(rect: .zero, scale: 2) == PixelSize(width: 1, height: 1))
        #expect(PixelSize.fitting(rect: CGRect(x: 0, y: 0, width: 0.2, height: 0.2), scale: 1) == PixelSize(width: 1, height: 1))
    }
}
