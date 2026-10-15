import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite struct ClickRoutingTests {
    private let targetID: UInt32 = 5

    private func window(id: UInt32, bounds: CGRect, layer: Int = 0) -> WindowInfo {
        WindowInfo(id: id, ownerPID: 1, ownerName: "App", title: "Window", bounds: bounds, layer: layer)
    }

    private var fullScreenTarget: WindowInfo {
        window(id: targetID, bounds: CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    @Test func mapsAppKitPointToCoreGraphicsOrigin() {
        let mapped = CoordinateMapper.coreGraphicsPoint(
            appKitPoint: CGPoint(x: 100, y: 900),
            primaryScreenHeight: 1000
        )

        #expect(mapped == CGPoint(x: 100, y: 100))
    }

    @Test func createsStepInsideTargetWindow() {
        let decision = ClickRouter.decide(
            clickPoint: CGPoint(x: 400, y: 300),
            windows: [fullScreenTarget],
            targetWindowID: targetID
        )

        #expect(decision == .step(point: CGPoint(x: 400, y: 300), normalized: NormalizedPoint(x: 0.5, y: 0.5)))
    }

    @Test func ignoresClickOnNonTargetWindow() {
        let other = window(id: 9, bounds: CGRect(x: 0, y: 0, width: 800, height: 600))

        let decision = ClickRouter.decide(
            clickPoint: CGPoint(x: 400, y: 300),
            windows: [other],
            targetWindowID: targetID
        )

        #expect(decision == .ignore)
    }

    @Test func ignoresClickWhenAnotherWindowCoversTarget() {
        let hud = window(id: 99, bounds: CGRect(x: 0, y: 0, width: 300, height: 200))

        let decision = ClickRouter.decide(
            clickPoint: CGPoint(x: 100, y: 100),
            windows: [hud, fullScreenTarget],
            targetWindowID: targetID
        )

        #expect(decision == .ignore)
    }

    @Test func ignoresClickOnSecondDisplayWindow() {
        let secondDisplay = window(id: 7, bounds: CGRect(x: 1920, y: 100, width: 1000, height: 800))

        let decision = ClickRouter.decide(
            clickPoint: CGPoint(x: 2600, y: 300),
            windows: [secondDisplay],
            targetWindowID: targetID
        )

        #expect(decision == .ignore)

        let secondDisplayTarget = window(id: targetID, bounds: CGRect(x: 1920, y: 100, width: 1000, height: 800))
        let hit = ClickRouter.decide(
            clickPoint: CGPoint(x: 2600, y: 300),
            windows: [secondDisplayTarget],
            targetWindowID: targetID
        )

        #expect(hit == .step(point: CGPoint(x: 2600, y: 300), normalized: NormalizedPoint(x: 0.68, y: 0.25)))
    }

    @Test func normalizedPointIsRelativeToTargetWindow() {
        let target = window(id: targetID, bounds: CGRect(x: 200, y: 100, width: 400, height: 800))

        let decision = ClickRouter.decide(
            clickPoint: CGPoint(x: 400, y: 500),
            windows: [target],
            targetWindowID: targetID
        )

        #expect(decision == .step(point: CGPoint(x: 400, y: 500), normalized: NormalizedPoint(x: 0.5, y: 0.5)))
    }

    @Test func normalizedPointIsNilForDegenerateWindowBounds() {
        #expect(NormalizedPoint.from(point: CGPoint(x: 10, y: 10), inWindowBounds: .zero) == nil)
        #expect(NormalizedPoint.from(point: CGPoint(x: 10, y: 10), inWindowBounds: CGRect(x: 0, y: 0, width: 100, height: 0)) == nil)
        #expect(NormalizedPoint.from(point: CGPoint(x: 50, y: 10), inWindowBounds: CGRect(x: 0, y: 0, width: 100, height: 20)) == NormalizedPoint(x: 0.5, y: 0.5))
    }
}
