import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import StepSnapCore

@Suite struct RecoveryScanTests {
    private func makeTempFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func manifest(startedAt: Date) -> Manifest {
        Manifest(
            scenarioName: "Проверка входа",
            startedAt: startedAt,
            steps: [
                ManifestStep(
                    index: 1,
                    name: "Открыть меню",
                    takenAt: startedAt,
                    pointNormalized: NormalizedPoint(x: 0.5, y: 0.5),
                    imageFileName: "step-001.png",
                    pixelWidth: 100,
                    pixelHeight: 200,
                    errorText: nil
                ),
                ManifestStep(
                    index: 2,
                    name: "",
                    takenAt: startedAt,
                    pointNormalized: nil,
                    imageFileName: "step-002.png",
                    pixelWidth: 100,
                    pixelHeight: 200,
                    errorText: nil
                ),
            ]
        )
    }

    private func makeScenarioFolder(in outputFolder: URL, manifest: Manifest?) throws -> URL {
        let folder = outputFolder.appendingPathComponent("сценарий-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let manifest {
            try ManifestFile.write(manifest, to: folder)
        }
        return folder
    }

    @Test func findsFolderWithManifestAndNoReport() throws {
        let outputFolder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let folder = try makeScenarioFolder(in: outputFolder, manifest: manifest(startedAt: Date()))

        let found = RecoveryScan.unfinished(in: outputFolder)

        #expect(found.count == 1)
        #expect(found[0].folder.standardizedFileURL == folder.standardizedFileURL)
        #expect(found[0].stepCount == 2)
    }

    @Test func skipsFolderWithReport() throws {
        let outputFolder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let folder = try makeScenarioFolder(in: outputFolder, manifest: manifest(startedAt: Date()))
        try Data("pdf".utf8).write(to: folder.appendingPathComponent(StepFileNames.reportFileName))

        #expect(RecoveryScan.unfinished(in: outputFolder).isEmpty)
    }

    @Test func skipsCorruptManifestWithoutThrowing() throws {
        let outputFolder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let folder = try makeScenarioFolder(in: outputFolder, manifest: nil)
        try Data("не json".utf8).write(to: ManifestFile.url(in: folder))

        #expect(RecoveryScan.unfinished(in: outputFolder).isEmpty)
    }

    @Test func skipsFolderWithoutManifest() throws {
        let outputFolder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        _ = try makeScenarioFolder(in: outputFolder, manifest: nil)

        #expect(RecoveryScan.unfinished(in: outputFolder).isEmpty)
    }

    @Test func missingOutputFolderReturnsEmpty() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        #expect(RecoveryScan.unfinished(in: missing).isEmpty)
    }

    @Test func sortsUnfinishedByStartDateDescending() throws {
        let outputFolder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let older = try makeScenarioFolder(in: outputFolder, manifest: manifest(startedAt: Date(timeIntervalSince1970: 1_000)))
        let newer = try makeScenarioFolder(in: outputFolder, manifest: manifest(startedAt: Date(timeIntervalSince1970: 2_000)))

        let found = RecoveryScan.unfinished(in: outputFolder)

        #expect(found.map(\.folder.standardizedFileURL) == [
            newer.standardizedFileURL,
            older.standardizedFileURL,
        ])
    }
}

@Suite struct ReportStepsTests {
    private func makeTempFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writePNG(width: Int, height: Int, to url: URL) throws {
        let image = ImageFixture.makeImage(width: width, height: height)
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    @Test func loadsStepsWithImages() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try writePNG(width: 40, height: 80, to: folder.appendingPathComponent("step-001.png"))

        let manifest = Manifest(
            scenarioName: "Сценарий",
            startedAt: Date(),
            steps: [
                ManifestStep(
                    index: 1,
                    name: "Открыть меню",
                    takenAt: Date(),
                    pointNormalized: NormalizedPoint(x: 0.25, y: 0.75),
                    imageFileName: "step-001.png",
                    pixelWidth: 40,
                    pixelHeight: 80,
                    errorText: nil
                ),
            ]
        )

        let steps = ReportSteps.from(manifest: manifest, folder: folder)

        #expect(steps.count == 1)
        #expect(steps[0].image?.width == 40)
        #expect(steps[0].image?.height == 80)
        #expect(steps[0].errorText == nil)
    }

    @Test func marksMissingImageAsFailed() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let manifest = Manifest(
            scenarioName: "Сценарий",
            startedAt: Date(),
            steps: [
                ManifestStep(
                    index: 1,
                    name: "",
                    takenAt: Date(),
                    pointNormalized: nil,
                    imageFileName: "step-001.png",
                    pixelWidth: 0,
                    pixelHeight: 0,
                    errorText: nil
                ),
                ManifestStep(
                    index: 2,
                    name: "",
                    takenAt: Date(),
                    pointNormalized: nil,
                    imageFileName: nil,
                    pixelWidth: 0,
                    pixelHeight: 0,
                    errorText: "Снимок не получился"
                ),
            ]
        )

        let steps = ReportSteps.from(manifest: manifest, folder: folder)

        #expect(steps[0].image == nil)
        #expect(steps[0].errorText != nil)
        #expect(steps[1].image == nil)
        #expect(steps[1].errorText == "Снимок не получился")
    }

    @Test func carriesNamesAndNormalizedPoints() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try writePNG(width: 10, height: 10, to: folder.appendingPathComponent("step-001.png"))

        let manifest = Manifest(
            scenarioName: "Сценарий",
            startedAt: Date(),
            steps: [
                ManifestStep(
                    index: 1,
                    name: "Нажать кнопку",
                    takenAt: Date(),
                    pointNormalized: NormalizedPoint(x: 0.1, y: 0.2),
                    imageFileName: "step-001.png",
                    pixelWidth: 10,
                    pixelHeight: 10,
                    errorText: nil
                ),
            ]
        )

        let steps = ReportSteps.from(manifest: manifest, folder: folder)

        #expect(steps[0].index == 1)
        #expect(steps[0].name == "Нажать кнопку")
        #expect(steps[0].pointNormalized == NormalizedPoint(x: 0.1, y: 0.2))
    }

    @Test func loadsExpectedResultImageFromItsFile() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try writePNG(width: 10, height: 10, to: folder.appendingPathComponent("step-001.png"))
        try writePNG(width: 30, height: 20, to: folder.appendingPathComponent("expected-001.png"))

        let manifest = Manifest(
            scenarioName: "Сценарий",
            startedAt: Date(),
            steps: [
                ManifestStep(
                    index: 1,
                    name: "Нажать кнопку",
                    takenAt: Date(),
                    pointNormalized: nil,
                    imageFileName: "step-001.png",
                    pixelWidth: 10,
                    pixelHeight: 10,
                    errorText: nil,
                    expectedResultFileName: "expected-001.png"
                ),
            ]
        )

        let steps = ReportSteps.from(manifest: manifest, folder: folder)

        #expect(steps[0].expectedResultImage?.width == 30)
        #expect(steps[0].expectedResultImage?.height == 20)
    }
}
