import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Запись одного сценария: шаги, снимки и манифест.
///
/// Устроено так, что порядок шагов равен порядку кликов: `noteClick` синхронный и вызывается
/// ровно в момент клика, а снимки уходят в очередь по одному. Задержка перед снимком нужна,
/// чтобы окно успело перерисоваться, и применяется только когда очередь пуста: иначе при
/// серии кликов отставание копилось бы.
@MainActor
public final class RecordingSession {
    public let scenarioName: String
    public let windowID: UInt32
    public let startedAt: Date
    public let folder: URL

    public private(set) var steps: [ManifestStep] = []
    /// Снятые кадры по номеру шага — чтобы собрать PDF, не перечитывая файлы.
    public private(set) var images: [Int: CGImage] = [:]
    public private(set) var lastCaptureError: CaptureError?
    /// Сколько снимков подряд не нашло окно. По этому счётчику приложение понимает,
    /// что целевое окно закрылось.
    public private(set) var consecutiveWindowNotFoundCount = 0

    public var latestIndex: Int? { steps.last?.index }

    /// Пауза записи: клики не превращаются в шаги, снимки не делаются.
    /// Уже собранное остаётся на месте, нумерация после снятия паузы продолжается.
    public var isPaused = false

    public var manifest: Manifest {
        Manifest(scenarioName: scenarioName, startedAt: startedAt, steps: steps)
    }

    private let source: FrameSource
    private let captureDelayMilliseconds: Int
    private let now: () -> Date
    private let sleep: (Int) async -> Void
    private let fileManager: FileManager
    private var tail: Task<Void, Never>?

    public init(
        scenarioName: String,
        outputFolder: URL,
        windowID: UInt32,
        source: FrameSource,
        captureDelayMilliseconds: Int,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Int) async -> Void = RecordingSession.systemSleep,
        fileManager: FileManager = .default
    ) throws {
        let startedAt = now()

        self.scenarioName = scenarioName
        self.windowID = windowID
        self.startedAt = startedAt
        self.source = source
        self.captureDelayMilliseconds = captureDelayMilliseconds
        self.now = now
        self.sleep = sleep
        self.fileManager = fileManager
        self.folder = try ScenarioFolder.create(
            at: outputFolder,
            named: ScenarioFolder.folderName(scenarioName: scenarioName, startedAt: startedAt),
            fileManager: fileManager
        )

        try writeManifest()
    }

    /// Записывает шаг и ставит снимок в очередь. Возвращает номер шага,
    /// либо `nil`, если запись на паузе и клик проигнорирован.
    ///
    /// Манифест пишется сразу, до снимка: если приложение упадёт, шаг не пропадёт.
    @discardableResult
    public func noteClick(at point: CGPoint, windowBounds: CGRect) -> Int? {
        guard !isPaused else { return nil }

        let index = steps.count + 1

        steps.append(
            ManifestStep(
                index: index,
                name: "",
                takenAt: now(),
                pointNormalized: NormalizedPoint.from(point: point, inWindowBounds: windowBounds),
                imageFileName: StepFileNames.imageFileName(forIndex: index),
                pixelWidth: 0,
                pixelHeight: 0,
                errorText: nil
            )
        )
        try? writeManifest()

        enqueueCapture(for: index)
        return index
    }

    public func nameStep(at index: Int, with name: String) {
        updateStep(index: index) { $0.name = name }
        try? writeManifest()
    }

    /// Ждёт, пока отработают все поставленные в очередь снимки.
    public func waitForPendingCaptures() async {
        await tail?.value
    }

    public static func systemSleep(milliseconds: Int) async {
        guard milliseconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }

    // MARK: - Очередь снимков

    private func enqueueCapture(for index: Int) {
        let needsDelay = (tail == nil)
        let previous = tail
        let delay = captureDelayMilliseconds
        let windowID = self.windowID

        tail = Task { [weak self] in
            await previous?.value
            guard let self else { return }

            if needsDelay, delay > 0 {
                await self.sleep(delay)
            }
            await self.performCapture(for: index, windowID: windowID)
        }
    }

    private func performCapture(for index: Int, windowID: UInt32) async {
        do {
            let frame = try await source.capture(windowID: windowID)
            try writePNG(frame.image, forIndex: index)

            images[index] = frame.image
            updateStep(index: index) { step in
                step.pixelWidth = frame.pixelSize.width
                step.pixelHeight = frame.pixelSize.height
                step.errorText = nil
            }
            lastCaptureError = nil
            consecutiveWindowNotFoundCount = 0
        } catch {
            let captureError = error as? CaptureError
            lastCaptureError = captureError
            if captureError == .windowNotFound {
                consecutiveWindowNotFoundCount += 1
            }
            updateStep(index: index) { step in
                step.imageFileName = nil
                step.pixelWidth = 0
                step.pixelHeight = 0
                step.errorText = "Снимок не получился"
            }
        }

        try? writeManifest()
    }

    // MARK: - Файлы

    private func writePNG(_ image: CGImage, forIndex index: Int) throws {
        let url = folder.appendingPathComponent(StepFileNames.imageFileName(forIndex: index))

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CaptureError.captureFailed("не удалось создать файл снимка")
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.captureFailed("не удалось записать файл снимка")
        }
    }

    private func writeManifest() throws {
        try ManifestFile.write(manifest, to: folder, fileManager: fileManager)
    }

    private func updateStep(index: Int, _ change: (inout ManifestStep) -> Void) {
        guard let position = steps.firstIndex(where: { $0.index == index }) else { return }
        change(&steps[position])
    }
}
