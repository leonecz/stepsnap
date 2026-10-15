import Foundation

/// Как подписываются шаги сценария.
public enum NamingMode: String, Codable, Sendable, CaseIterable {
    /// Панель записи сразу предлагает название для каждого шага.
    case immediate
    /// Шаги копятся без названий, имена вводятся списком после остановки.
    case afterStop
}

public struct Settings: Equatable, Sendable {
    public var outputFolder: URL
    public var askNameForEachStep: Bool
    public var namingMode: NamingMode
    public var captureDelayMilliseconds: Int
    public var markClickPoint: Bool

    /// Допустимый диапазон задержки перед снимком.
    public static let captureDelayRange = 0...5000

    public init(
        outputFolder: URL,
        askNameForEachStep: Bool,
        namingMode: NamingMode,
        captureDelayMilliseconds: Int,
        markClickPoint: Bool
    ) {
        self.outputFolder = outputFolder
        self.askNameForEachStep = askNameForEachStep
        self.namingMode = namingMode
        self.captureDelayMilliseconds = captureDelayMilliseconds
        self.markClickPoint = markClickPoint
    }

    public static var standard: Settings {
        Settings(
            outputFolder: SettingsStore.defaultOutputFolder(),
            askNameForEachStep: true,
            namingMode: .immediate,
            captureDelayMilliseconds: 250,
            markClickPoint: true
        )
    }
}
