import Foundation
import Observation

/// Подпись шагов «на лету»: то, что набрано в поле панели записи.
///
/// Правило простое и однозначное: набранное закрепляется за последним шагом
/// **в момент закрепления**. Клик сначала закрепляет текст за предыдущим шагом,
/// и только потом создаётся новый шаг.
@MainActor
@Observable
public final class StepNaming {
    public var isEnabled: Bool
    public private(set) var fieldText = ""

    private let session: RecordingSession

    public init(session: RecordingSession, enabled: Bool) {
        self.session = session
        self.isEnabled = enabled
    }

    public func updateFieldText(_ text: String) {
        fieldText = isEnabled ? text : ""
    }

    /// Вызывается перед записью нового шага.
    public func clickRecorded() {
        commitPendingText()
    }

    /// Enter: закрепить набранное за последним шагом.
    public func commitFieldText() {
        commitPendingText()
    }

    private func commitPendingText() {
        let trimmed = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isEnabled, !trimmed.isEmpty, let index = session.latestIndex {
            session.nameStep(at: index, with: trimmed)
        }
        fieldText = ""
    }
}
