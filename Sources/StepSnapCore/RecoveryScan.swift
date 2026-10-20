import CoreGraphics
import Foundation
import ImageIO

/// Сценарий, который начали и не закончили: манифест и снимки есть, PDF нет.
public struct UnfinishedScenario: Equatable, Sendable {
    public var folder: URL
    public var manifest: Manifest
    public var stepCount: Int

    public init(folder: URL, manifest: Manifest, stepCount: Int) {
        self.folder = folder
        self.manifest = manifest
        self.stepCount = stepCount
    }
}

public enum RecoveryScan {
    /// Ищет незавершённые сценарии в выходной папке. Никогда не выбрасывает наружу:
    /// битый манифест или недоступная папка — это пропущенный сценарий, не ошибка запуска.
    public static func unfinished(
        in outputFolder: URL,
        fileManager: FileManager = .default
    ) -> [UnfinishedScenario] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: outputFolder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var found: [UnfinishedScenario] = []

        for entry in entries {
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { continue }
            guard ManifestFile.exists(in: entry) else { continue }

            let report = entry.appendingPathComponent(StepFileNames.reportFileName)
            guard !fileManager.fileExists(atPath: report.path) else { continue }
            guard let manifest = try? ManifestFile.read(from: entry) else { continue }

            found.append(UnfinishedScenario(folder: entry, manifest: manifest, stepCount: manifest.steps.count))
        }

        return found.sorted { $0.manifest.startedAt > $1.manifest.startedAt }
    }
}

/// Собирает шаги отчёта из манифеста и файлов на диске.
public enum ReportSteps {
    public static func from(manifest: Manifest, folder: URL) -> [ReportStep] {
        manifest.steps.map { step in
            let image = step.imageFileName.flatMap { loadImage(at: folder.appendingPathComponent($0)) }
            let expectedResult = step.expectedResultFileName.flatMap {
                loadImage(at: folder.appendingPathComponent($0))
            }

            return ReportStep(
                index: step.index,
                name: step.name,
                image: image,
                pointNormalized: step.pointNormalized,
                errorText: image == nil ? (step.errorText ?? "Снимок не найден") : step.errorText,
                expectedResultImage: expectedResult
            )
        }
    }

    private static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
