import CoreGraphics
import Foundation
import Testing
@testable import StepSnapCore

@Suite @MainActor struct StepNamingTests {
    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)

    private func makeSession() throws -> (session: RecordingSession, outputFolder: URL) {
        let outputFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let session = try RecordingSession(
            scenarioName: "Проверка входа",
            outputFolder: outputFolder,
            windowID: 7,
            source: FakeFrameSource(image: ImageFixture.makeImage(width: 2, height: 2)),
            captureDelayMilliseconds: 0,
            sleep: { _ in }
        )
        return (session, outputFolder)
    }

    /// Повторяет то, что делает AppState на каждый клик: сначала закрепляем набранное
    /// за предыдущим шагом, потом записываем новый шаг.
    private func click(_ naming: StepNaming, _ session: RecordingSession) {
        naming.clickRecorded()
        session.noteClick(at: CGPoint(x: 10, y: 10), windowBounds: bounds)
    }

    @Test func typingThenClickNamesPreviousStep() throws {
        let (session, outputFolder) = try makeSession()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let naming = StepNaming(session: session, enabled: true)

        click(naming, session)
        naming.updateFieldText("Открыть меню")
        click(naming, session)

        #expect(session.steps[0].name == "Открыть меню")
        #expect(naming.fieldText.isEmpty)
    }

    @Test func enterNamesLatestStep() throws {
        let (session, outputFolder) = try makeSession()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let naming = StepNaming(session: session, enabled: true)

        click(naming, session)
        naming.updateFieldText("Войти")
        naming.commitFieldText()

        #expect(session.steps[0].name == "Войти")
        #expect(naming.fieldText.isEmpty)
    }

    @Test func emptyFieldChangesNothing() throws {
        let (session, outputFolder) = try makeSession()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let naming = StepNaming(session: session, enabled: true)

        click(naming, session)
        naming.updateFieldText("   ")
        naming.commitFieldText()
        naming.clickRecorded()

        #expect(session.steps[0].name.isEmpty)
        #expect(naming.fieldText.isEmpty)
    }

    @Test func disabledNamingIgnoresEverything() throws {
        let (session, outputFolder) = try makeSession()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let naming = StepNaming(session: session, enabled: false)

        click(naming, session)
        naming.updateFieldText("Открыть меню")
        naming.commitFieldText()
        click(naming, session)

        #expect(naming.fieldText.isEmpty)
        #expect(session.steps.allSatisfy { $0.name.isEmpty })
    }

    @Test func previousStepIsNotRenamedTwice() throws {
        let (session, outputFolder) = try makeSession()
        defer { try? FileManager.default.removeItem(at: outputFolder) }
        let naming = StepNaming(session: session, enabled: true)

        click(naming, session)
        naming.updateFieldText("Первый")
        click(naming, session)
        naming.updateFieldText("Второй")
        click(naming, session)

        #expect(session.steps.map(\.name) == ["Первый", "Второй", ""])
    }
}
