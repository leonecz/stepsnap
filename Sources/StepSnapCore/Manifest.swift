import Foundation

/// Один шаг сценария в манифесте: то, что переживает падение приложения.
public struct ManifestStep: Codable, Equatable, Sendable {
    public var index: Int
    public var name: String
    public var takenAt: Date
    public var pointNormalized: NormalizedPoint?
    /// `nil`, если снимок не получился — тогда заполнен `errorText`.
    public var imageFileName: String?
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var errorText: String?
}

public struct Manifest: Codable, Equatable, Sendable {
    public var scenarioName: String
    public var startedAt: Date
    public var steps: [ManifestStep]
}

public enum StepFileNames {
    public static let reportFileName = "отчёт.pdf"

    public static func imageFileName(forIndex index: Int) -> String {
        let padded = String(format: "%03d", index)
        return "step-\(padded).png"
    }
}

/// Файл `steps.json`: название сценария, время начала и все шаги.
///
/// Наличие манифеста без готового PDF и означает незавершённый сценарий.
public enum ManifestFile {
    public static let fileName = "steps.json"

    public static func url(in folder: URL) -> URL {
        folder.appendingPathComponent(fileName)
    }

    public static func exists(in folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: url(in: folder).path)
    }

    /// Пишет манифест атомарно: сначала во временный файл, затем подменяет им основной.
    public static func write(
        _ manifest: Manifest,
        to folder: URL,
        fileManager: FileManager = .default
    ) throws {
        let target = url(in: folder)
        let temporary = folder.appendingPathComponent(fileName + ".tmp")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try encoder.encode(manifest).write(to: temporary, options: .atomic)

        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(target, withItemAt: temporary, backupItemName: nil, options: [])
        } else {
            try fileManager.moveItem(at: temporary, to: target)
        }
    }

    public static func read(from folder: URL) throws -> Manifest {
        let data = try Data(contentsOf: url(in: folder))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(Manifest.self, from: data)
    }
}
