import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite struct WindowInfoTests {
    private func rawDictionary(
        number: Any? = 42 as NSNumber,
        pid: Any? = 777 as NSNumber,
        ownerName: Any? = "Simulator" as NSString,
        title: Any? = "iPhone 15" as NSString,
        layer: Any? = 0 as NSNumber,
        bounds: Any? = ["X": 100, "Y": 200, "Width": 800, "Height": 600] as CFDictionary
    ) -> [String: Any] {
        var raw: [String: Any] = [:]
        if let number { raw[kCGWindowNumber as String] = number }
        if let pid { raw[kCGWindowOwnerPID as String] = pid }
        if let ownerName { raw[kCGWindowOwnerName as String] = ownerName }
        if let title { raw[kCGWindowName as String] = title }
        if let layer { raw[kCGWindowLayer as String] = layer }
        if let bounds { raw[kCGWindowBounds as String] = bounds }
        return raw
    }

    private func window(
        id: UInt32,
        ownerPID: pid_t = 1,
        ownerName: String = "App",
        title: String = "Window",
        bounds: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
        layer: Int = 0
    ) -> WindowInfo {
        WindowInfo(id: id, ownerPID: ownerPID, ownerName: ownerName, title: title, bounds: bounds, layer: layer)
    }

    @Test func parsesRawWindowDictionary() {
        let info = WindowInfo.from(raw: rawDictionary())

        #expect(info?.id == 42)
        #expect(info?.ownerPID == 777)
        #expect(info?.ownerName == "Simulator")
        #expect(info?.title == "iPhone 15")
        #expect(info?.layer == 0)
        #expect(info?.bounds == CGRect(x: 100, y: 200, width: 800, height: 600))
    }

    @Test func returnsNilWithoutWindowNumber() {
        #expect(WindowInfo.from(raw: rawDictionary(number: nil)) == nil)
    }

    @Test func returnsNilWithoutBounds() {
        #expect(WindowInfo.from(raw: rawDictionary(bounds: nil)) == nil)
    }

    @Test func labelCombinesOwnerAndTitle() {
        #expect(window(id: 1, ownerName: "Simulator", title: "iPhone 15").label == "Simulator — iPhone 15")
    }

    @Test func labelFallsBackToOwner() {
        #expect(window(id: 1, ownerName: "Simulator", title: "").label == "Simulator")
    }

    @Test func labelFallsBackToTitle() {
        #expect(window(id: 1, ownerName: "", title: "iPhone 15").label == "iPhone 15")
    }

    @Test func filterDropsOtherLayersSmallWindowsAndOwnProcess() {
        let ownPID: pid_t = 777
        let all = [
            window(id: 1, ownerPID: 111, bounds: CGRect(x: 0, y: 0, width: 800, height: 600), layer: 1),
            window(id: 2, ownerPID: 222, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
            window(id: 3, ownerPID: ownPID, bounds: CGRect(x: 0, y: 0, width: 800, height: 600)),
            window(id: 4, ownerPID: 444, ownerName: "", bounds: CGRect(x: 0, y: 0, width: 800, height: 600)),
            window(id: 5, ownerPID: 555, bounds: CGRect(x: 0, y: 0, width: 800, height: 600)),
        ]

        #expect(WindowFilter.capturable(all, ownPID: ownPID).map(\.id) == [5])
    }

    @Test func filterKeepsFrontToBackOrder() {
        let all = [
            window(id: 9, ownerPID: 111),
            window(id: 8, ownerPID: 222),
            window(id: 7, ownerPID: 333),
        ]

        #expect(WindowFilter.capturable(all, ownPID: 999).map(\.id) == [9, 8, 7])
    }
}
