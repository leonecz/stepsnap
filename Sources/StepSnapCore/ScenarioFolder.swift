import Foundation

public enum ScenarioFolderError: Error, Equatable {
    case outsideOutputFolder
}

/// Папка одного сценария внутри выходной папки.
public enum ScenarioFolder {
    public static let maxNameLength = 60
    public static let fallbackName = "сценарий"

    /// Приводит имя сценария к виду, пригодному для имени папки.
    /// Никогда не возвращает пустую строку и ничего, что могло бы увести запись
    /// из выходной папки вверх по дереву.
    public static func sanitize(_ raw: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
            .union(.controlCharacters)
            .union(.whitespaces)

        let replaced = String(raw.unicodeScalars.map { scalar in
            forbidden.contains(scalar) ? "-" : Character(scalar)
        })

        let collapsed = replaced
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")

        let trimmed = collapsed
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
            .prefix(maxNameLength)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))

        return trimmed.isEmpty ? fallbackName : String(trimmed)
    }

    public static func folderName(
        scenarioName: String,
        startedAt: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        return "\(sanitize(scenarioName))-\(formatter.string(from: startedAt))"
    }

    /// Создаёт папку сценария и возвращает её. Имя ещё раз санитизируется,
    /// а результат проверяется на то, что он лежит внутри выходной папки.
    @discardableResult
    public static func create(
        at outputFolder: URL,
        named name: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        let folder = outputFolder.appendingPathComponent(sanitize(name), isDirectory: true)
        let outputPath = outputFolder.standardizedFileURL.path
        let folderPath = folder.standardizedFileURL.path

        guard folderPath.hasPrefix(outputPath + "/") else {
            throw ScenarioFolderError.outsideOutputFolder
        }

        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
