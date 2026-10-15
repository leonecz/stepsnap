import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite struct ScenarioFolderTests {
    private func makeTempFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func sanitizeReplacesPathSeparators() {
        #expect(ScenarioFolder.sanitize("a/b:c") == "a-b-c")
    }

    @Test func sanitizeCollapsesRepeats() {
        #expect(ScenarioFolder.sanitize("a///b   c") == "a-b-c")
    }

    @Test func sanitizeFallsBackWhenEmpty() {
        #expect(ScenarioFolder.sanitize("") == "сценарий")
        #expect(ScenarioFolder.sanitize("   ") == "сценарий")
        #expect(ScenarioFolder.sanitize("..") == "сценарий")
        #expect(ScenarioFolder.sanitize("///") == "сценарий")
    }

    @Test func sanitizeCapsLength() {
        let long = String(repeating: "a", count: 500)

        #expect(ScenarioFolder.sanitize(long).count <= ScenarioFolder.maxNameLength)
    }

    @Test func folderNameIsDeterministic() {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 15
        components.hour = 12
        components.minute = 34
        components.second = 56

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "GMT")!
        let startedAt = calendar.date(from: components)!

        let name = ScenarioFolder.folderName(
            scenarioName: "Проверка входа",
            startedAt: startedAt,
            timeZone: TimeZone(identifier: "GMT")!
        )

        #expect(name == "Проверка-входа-2026-10-15-123456")
    }

    @Test func folderStaysInsideOutputFolder() throws {
        let outputFolder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        let created = try ScenarioFolder.create(at: outputFolder, named: "../../etc")

        #expect(created.standardizedFileURL.path.hasPrefix(outputFolder.standardizedFileURL.path))
        #expect(FileManager.default.fileExists(atPath: created.path))
    }
}
