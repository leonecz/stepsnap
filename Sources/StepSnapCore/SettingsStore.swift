import Foundation

/// Настройки StepSnap поверх `UserDefaults`.
public final class SettingsStore {
    enum Keys {
        static let outputFolder = "outputFolder"
        static let askNameForEachStep = "askNameForEachStep"
        static let namingMode = "namingMode"
        static let captureDelayMilliseconds = "captureDelayMilliseconds"
        static let markClickPoint = "markClickPoint"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var current: Settings {
        let fallback = Settings.standard

        let folder = defaults.string(forKey: Keys.outputFolder)
            .map { URL(fileURLWithPath: $0) } ?? fallback.outputFolder
        let askName = defaults.object(forKey: Keys.askNameForEachStep) as? Bool
            ?? fallback.askNameForEachStep
        let mode = defaults.string(forKey: Keys.namingMode)
            .flatMap(NamingMode.init(rawValue:)) ?? fallback.namingMode
        let delay = defaults.object(forKey: Keys.captureDelayMilliseconds) as? Int
            ?? fallback.captureDelayMilliseconds
        let mark = defaults.object(forKey: Keys.markClickPoint) as? Bool
            ?? fallback.markClickPoint

        return Settings(
            outputFolder: folder,
            askNameForEachStep: askName,
            namingMode: mode,
            captureDelayMilliseconds: Self.clampDelay(delay),
            markClickPoint: mark
        )
    }

    public func update(_ settings: Settings) {
        defaults.set(settings.outputFolder.path, forKey: Keys.outputFolder)
        defaults.set(settings.askNameForEachStep, forKey: Keys.askNameForEachStep)
        defaults.set(settings.namingMode.rawValue, forKey: Keys.namingMode)
        defaults.set(Self.clampDelay(settings.captureDelayMilliseconds), forKey: Keys.captureDelayMilliseconds)
        defaults.set(settings.markClickPoint, forKey: Keys.markClickPoint)
    }

    public static func defaultOutputFolder() -> URL {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        return documents.appendingPathComponent("StepSnap", isDirectory: true)
    }

    static func clampDelay(_ value: Int) -> Int {
        min(max(value, Settings.captureDelayRange.lowerBound), Settings.captureDelayRange.upperBound)
    }
}
