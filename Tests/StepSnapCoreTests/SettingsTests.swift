import Foundation
import Testing
@testable import StepSnapCore

@Suite struct SettingsTests {
    /// Свежий изолированный домен настроек, который тест потом за собой убирает.
    private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "stepsnap.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @Test func standardValuesAreUsedWhenNothingStored() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        #expect(store.current == Settings.standard)
    }

    @Test func storedValuesAreReadBack() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var written = Settings.standard
        written.outputFolder = URL(fileURLWithPath: "/tmp/stepsnap-output")
        written.askNameForEachStep = false
        written.namingMode = .afterStop
        written.captureDelayMilliseconds = 1200
        written.markClickPoint = false

        SettingsStore(defaults: defaults).update(written)

        let reloaded = SettingsStore(defaults: UserDefaults(suiteName: suiteName)!).current

        #expect(reloaded == written)
    }

    @Test func delayIsClampedToRange() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        var tooBig = Settings.standard
        tooBig.captureDelayMilliseconds = 99999
        store.update(tooBig)
        #expect(store.current.captureDelayMilliseconds == 5000)

        var tooSmall = Settings.standard
        tooSmall.captureDelayMilliseconds = -5
        store.update(tooSmall)
        #expect(store.current.captureDelayMilliseconds == 0)

        // Значение, положенное в домен в обход store, на чтении тоже клампится.
        defaults.set(99999, forKey: "captureDelayMilliseconds")
        #expect(store.current.captureDelayMilliseconds == 5000)
    }

    @Test func unknownNamingModeFallsBackToImmediate() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("weird", forKey: "namingMode")

        #expect(SettingsStore(defaults: defaults).current.namingMode == .immediate)
    }

    @Test func defaultOutputFolderIsDocumentsStepSnap() {
        let components = SettingsStore.defaultOutputFolder().pathComponents

        #expect(Array(components.suffix(2)) == ["Documents", "StepSnap"])
    }
}
