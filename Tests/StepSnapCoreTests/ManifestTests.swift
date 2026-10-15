import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite struct ManifestTests {
    private func makeTempFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sampleManifest() -> Manifest {
        Manifest(
            scenarioName: "Проверка входа",
            startedAt: Date(timeIntervalSince1970: 1_763_000_000),
            steps: [
                ManifestStep(
                    index: 1,
                    name: "Открыть меню",
                    takenAt: Date(timeIntervalSince1970: 1_763_000_010),
                    pointNormalized: NormalizedPoint(x: 0.5, y: 0.25),
                    imageFileName: "step-001.png",
                    pixelWidth: 906,
                    pixelHeight: 1942,
                    errorText: nil
                ),
                ManifestStep(
                    index: 2,
                    name: "",
                    takenAt: Date(timeIntervalSince1970: 1_763_000_020),
                    pointNormalized: nil,
                    imageFileName: nil,
                    pixelWidth: 0,
                    pixelHeight: 0,
                    errorText: "Снимок не получился"
                ),
            ]
        )
    }

    @Test func manifestRoundTrips() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let manifest = sampleManifest()

        try ManifestFile.write(manifest, to: folder)
        let read = try ManifestFile.read(from: folder)

        #expect(read == manifest)
    }

    @Test func manifestWriteLeavesNoTempFiles() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try ManifestFile.write(sampleManifest(), to: folder)
        try ManifestFile.write(sampleManifest(), to: folder)

        let contents = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(contents == [ManifestFile.fileName])
    }

    @Test func manifestReadFailsOnCorruptFile() throws {
        let folder = makeTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try Data("это не json".utf8).write(to: ManifestFile.url(in: folder))

        #expect(throws: (any Error).self) {
            try ManifestFile.read(from: folder)
        }
    }

    @Test func imageFileNamesArePadded() {
        #expect(StepFileNames.imageFileName(forIndex: 1) == "step-001.png")
        #expect(StepFileNames.imageFileName(forIndex: 42) == "step-042.png")
        #expect(StepFileNames.imageFileName(forIndex: 1234) == "step-1234.png")
        #expect(StepFileNames.reportFileName == "отчёт.pdf")
    }
}
