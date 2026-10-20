import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite @MainActor struct RecordingSessionTests {
    private let windowID: UInt32 = 7
    private let fullBounds = CGRect(x: 0, y: 0, width: 100, height: 100)

    private func makeTempFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeSession(
        source: FakeFrameSource,
        delay: Int = 0,
        sleepCounter: (@Sendable (Int) -> Void)? = nil
    ) throws -> (session: RecordingSession, outputFolder: URL) {
        let outputFolder = makeTempFolder()
        let session = try RecordingSession(
            scenarioName: "Проверка входа",
            outputFolder: outputFolder,
            windowID: windowID,
            source: source,
            captureDelayMilliseconds: delay,
            sleep: { milliseconds in sleepCounter?(milliseconds) }
        )
        return (session, outputFolder)
    }

    @Test func clickCreatesStepWithImageAndManifest() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 4, height: 8))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        let index = session.noteClick(at: CGPoint(x: 50, y: 50), windowBounds: fullBounds)
        await session.waitForPendingCaptures()

        #expect(index == 1)
        #expect(source.captureCount == 1)
        #expect(source.capturedWindowIDs == [windowID])

        let png = session.folder.appendingPathComponent("step-001.png")
        #expect(FileManager.default.fileExists(atPath: png.path))

        let manifest = try ManifestFile.read(from: session.folder)
        #expect(manifest.steps.count == 1)
        #expect(manifest.steps[0].pixelWidth == 4)
        #expect(manifest.steps[0].pixelHeight == 8)
        #expect(manifest.steps[0].pointNormalized == NormalizedPoint(x: 0.5, y: 0.5))
        #expect(manifest.steps[0].errorText == nil)
    }

    @Test func burstKeepsClickOrder() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2), delay: .milliseconds(5))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        for _ in 0..<5 {
            session.noteClick(at: CGPoint(x: 50, y: 50), windowBounds: fullBounds)
        }
        await session.waitForPendingCaptures()

        #expect(session.steps.map(\.index) == [1, 2, 3, 4, 5])
        #expect(session.steps.map(\.imageFileName) == [
            "step-001.png", "step-002.png", "step-003.png", "step-004.png", "step-005.png",
        ])
        for index in 1...5 {
            let png = session.folder.appendingPathComponent("step-00\(index).png")
            #expect(FileManager.default.fileExists(atPath: png.path))
        }
    }

    @Test func delayIsSkippedWhileCaptureIsPending() async throws {
        let counter = SleepCounter()
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2), delay: .milliseconds(20))
        let (session, outputFolder) = try makeSession(source: source, delay: 200, sleepCounter: { counter.record($0) })
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        session.noteClick(at: CGPoint(x: 2, y: 2), windowBounds: fullBounds)
        session.noteClick(at: CGPoint(x: 3, y: 3), windowBounds: fullBounds)
        await session.waitForPendingCaptures()

        #expect(counter.calls == [200])
    }

    @Test func failedCaptureKeepsStepWithError() async throws {
        let source = FakeFrameSource(error: CaptureError.windowNotFound)
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 50, y: 50), windowBounds: fullBounds)
        await session.waitForPendingCaptures()

        #expect(session.steps.count == 1)
        #expect(session.steps[0].imageFileName == nil)
        #expect(session.steps[0].errorText != nil)
        #expect(session.lastCaptureError == .windowNotFound)
        #expect(session.consecutiveWindowNotFoundCount == 1)

        let png = session.folder.appendingPathComponent("step-001.png")
        #expect(!FileManager.default.fileExists(atPath: png.path))

        let manifest = try ManifestFile.read(from: session.folder)
        #expect(manifest.steps.count == 1)
        #expect(manifest.steps[0].errorText != nil)
    }

    @Test func successfulCaptureClearsFailureCounter() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        await session.waitForPendingCaptures()

        #expect(session.consecutiveWindowNotFoundCount == 0)
        #expect(session.lastCaptureError == nil)
    }

    @Test func namingUpdatesManifest() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        session.nameStep(at: 1, with: "Открыть меню")
        await session.waitForPendingCaptures()

        #expect(session.steps[0].name == "Открыть меню")
        #expect(try ManifestFile.read(from: session.folder).steps[0].name == "Открыть меню")
        #expect(session.latestIndex == 1)
    }

    @Test func manifestReflectsEveryClickImmediately() async throws {        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 50, y: 50), windowBounds: fullBounds)

        let onDisk = try ManifestFile.read(from: session.folder)
        #expect(onDisk.steps.count == 1)
        #expect(onDisk.steps[0].name.isEmpty)
        #expect(onDisk.scenarioName == "Проверка входа")

        await session.waitForPendingCaptures()
    }

    @Test func attachingExpectedResultWritesFileAndManifest() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        await session.waitForPendingCaptures()

        let expected = ImageFixture.makeImage(width: 6, height: 4)
        try session.attachExpectedResult(expected, toStep: 1)

        #expect(session.steps[0].expectedResultFileName == "expected-001.png")
        #expect(session.expectedImages[1]?.width == 6)
        #expect(session.expectedImages[1]?.height == 4)

        let png = session.folder.appendingPathComponent("expected-001.png")
        #expect(FileManager.default.fileExists(atPath: png.path))

        let manifest = try ManifestFile.read(from: session.folder)
        #expect(manifest.steps[0].expectedResultFileName == "expected-001.png")
    }

    @Test func newExpectedResultReplacesPreviousOne() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        await session.waitForPendingCaptures()

        try session.attachExpectedResult(ImageFixture.makeImage(width: 6, height: 4), toStep: 1)
        try session.attachExpectedResult(ImageFixture.makeImage(width: 9, height: 3), toStep: 1)

        #expect(session.expectedImages[1]?.width == 9)

        let manifest = try ManifestFile.read(from: session.folder)
        #expect(manifest.steps[0].expectedResultFileName == "expected-001.png")
    }

    @Test func removingExpectedResultDeletesFileAndManifestField() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        await session.waitForPendingCaptures()
        try session.attachExpectedResult(ImageFixture.makeImage(width: 6, height: 4), toStep: 1)

        session.removeExpectedResult(fromStep: 1)

        let png = session.folder.appendingPathComponent("expected-001.png")
        #expect(!FileManager.default.fileExists(atPath: png.path))
        #expect(session.expectedImages[1] == nil)
        #expect(session.steps[0].expectedResultFileName == nil)
        #expect(try ManifestFile.read(from: session.folder).steps[0].expectedResultFileName == nil)
    }

    @Test func deletingLastStepRemovesItWithItsFiles() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        await session.waitForPendingCaptures()
        session.noteClick(at: CGPoint(x: 2, y: 2), windowBounds: fullBounds)
        await session.waitForPendingCaptures()
        try session.attachExpectedResult(ImageFixture.makeImage(width: 6, height: 4), toStep: 2)

        session.deleteLastStep()

        #expect(session.steps.map(\.index) == [1])
        #expect(session.expectedImages[2] == nil)
        #expect(session.images[2] == nil)

        for name in ["step-002.png", "expected-002.png"] {
            #expect(!FileManager.default.fileExists(atPath: session.folder.appendingPathComponent(name).path))
        }
        #expect(try ManifestFile.read(from: session.folder).steps.map(\.index) == [1])

        // Нумерация продолжается с того же места.
        #expect(session.noteClick(at: CGPoint(x: 3, y: 3), windowBounds: fullBounds) == 2)
        await session.waitForPendingCaptures()
    }

    @Test func deletingLastStepWhileCaptureIsPendingLeavesNoFiles() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2), delay: .milliseconds(50))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        session.deleteLastStep()
        await session.waitForPendingCaptures()

        #expect(session.steps.isEmpty)
        #expect(session.images.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: session.folder.appendingPathComponent("step-001.png").path))
        #expect(try ManifestFile.read(from: session.folder).steps.isEmpty)
    }

    @Test func pausedClicksDoNotCreateSteps() async throws {
        let source = FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2))
        let (session, outputFolder) = try makeSession(source: source)
        defer { try? FileManager.default.removeItem(at: outputFolder) }

        session.noteClick(at: CGPoint(x: 1, y: 1), windowBounds: fullBounds)
        await session.waitForPendingCaptures()
        #expect(session.steps.count == 1)

        // На паузе клик не создаёт шаг, не делает снимок и не трогает манифест.
        session.isPaused = true
        let ignored = session.noteClick(at: CGPoint(x: 2, y: 2), windowBounds: fullBounds)
        await session.waitForPendingCaptures()

        #expect(ignored == nil)
        #expect(session.steps.count == 1)
        #expect(source.captureCount == 1)
        #expect(try ManifestFile.read(from: session.folder).steps.count == 1)

        // После снятия паузы нумерация продолжается без разрыва.
        session.isPaused = false
        #expect(session.noteClick(at: CGPoint(x: 3, y: 3), windowBounds: fullBounds) == 2)
        await session.waitForPendingCaptures()

        #expect(session.steps.map(\.index) == [1, 2])
        #expect(source.captureCount == 2)
    }
}

/// Считает вызовы задержки: в тестах она подменяется, поэтому никаких ожиданий по времени.
private final class SleepCounter: @unchecked Sendable {
    private(set) var calls: [Int] = []

    func record(_ milliseconds: Int) {
        calls.append(milliseconds)
    }
}
