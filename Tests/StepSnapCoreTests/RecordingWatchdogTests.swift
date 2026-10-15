import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite struct RecordingWatchdogTests {
    private func window(id: UInt32) -> WindowInfo {
        WindowInfo(id: id, ownerPID: 1, ownerName: "App", title: "Window", bounds: CGRect(x: 0, y: 0, width: 800, height: 600), layer: 0)
    }

    @Test func stopsWhenTargetIsGoneFromWindowList() {
        let windows = [window(id: 5), window(id: 6)]

        #expect(RecordingWatchdog.shouldStop(windowID: 7, windows: windows, consecutiveWindowNotFoundCount: 0))
        #expect(!RecordingWatchdog.shouldStop(windowID: 6, windows: windows, consecutiveWindowNotFoundCount: 0))
    }

    @Test func stopsWhenCapturesKeepLosingTheWindow() {
        let windows = [window(id: 6)]

        #expect(!RecordingWatchdog.shouldStop(windowID: 6, windows: windows, consecutiveWindowNotFoundCount: 4))
        #expect(RecordingWatchdog.shouldStop(windowID: 6, windows: windows, consecutiveWindowNotFoundCount: 5))
    }

    @Test func emptyWindowListMeansTargetIsGone() {
        #expect(RecordingWatchdog.shouldStop(windowID: 6, windows: [], consecutiveWindowNotFoundCount: 0))
    }
}
