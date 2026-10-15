import AppKit
import Observation
import StepSnapCore

/// Состояние приложения: фаза, текущий сценарий, сессия записи.
@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case idle
        case naming
        case pickingWindow
        case recording
        case finished
    }

    enum StopReason: Equatable {
        case stoppedByUser
        case targetWindowClosed
    }

    let settingsStore: SettingsStore

    var phase: Phase = .idle {
        didSet {
            if phase != oldValue {
                onPhaseChanged?(phase)
            }
        }
    }

    var scenarioName = ""
    var selectedWindow: WindowInfo?
    var session: RecordingSession?
    var stepCount = 0
    var latestImage: CGImage?
    var lastReportURL: URL?
    var errorMessage: String?
    /// Почему остановились: от этого зависит текст в поповере.
    var stopReason: StopReason = .stoppedByUser

    /// Подпись шагов «на лету» — живёт, пока идёт запись.
    var naming: StepNaming?
    var askNameForEachStep = false
    /// Чекбокс подписи показывается только в режиме «сразу»: в режиме «потом»
    /// подписи в панели места нет, там список после остановки.
    var namingToggleVisible = false
    var showsNamingField = false
    /// Панель записи должна пересчитать размер (появляется или исчезает поле названия).
    var onHUDNeedsResize: (() -> Void)?

    /// Режим «потом»: после остановки сначала подписываем шаги, потом сохраняем.
    var pendingStepList = false
    var stepNames: [Int: String] = [:]

    /// AppKit-обвязка подписывается сюда: показать HUD, закрыть поповер, сменить иконку.
    var onPhaseChanged: ((Phase) -> Void)?

    private let frameSource = ScreenCaptureFrameSource()
    private var clickMonitor: ClickMonitor?

    /// Сколько снимков подряд без окна означают, что окно закрылось.
    private let windowNotFoundLimit = 5

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    // MARK: - Фазы

    func beginScenario() {
        scenarioName = ""
        errorMessage = nil
        stopReason = .stoppedByUser
        phase = .naming
    }

    func confirmScenarioName() {
        let trimmed = scenarioName.trimmingCharacters(in: .whitespacesAndNewlines)
        scenarioName = trimmed.isEmpty ? "Сценарий" : trimmed
        errorMessage = nil
        phase = .pickingWindow
    }

    func startRecording(window: WindowInfo) {
        errorMessage = nil

        guard Permissions.screenRecordingGranted() else {
            errorMessage = "Нужно разрешение на запись экрана. Выдайте его и перезапустите приложение."
            phase = .pickingWindow
            return
        }

        let settings = settingsStore.current

        do {
            let session = try RecordingSession(
                scenarioName: scenarioName,
                outputFolder: settings.outputFolder,
                windowID: window.id,
                source: frameSource,
                captureDelayMilliseconds: settings.captureDelayMilliseconds
            )
            self.session = session
            selectedWindow = window
            stepCount = 0
            latestImage = nil
            lastReportURL = nil
            pendingStepList = false
            stepNames = [:]

            askNameForEachStep = settings.askNameForEachStep
            namingToggleVisible = settings.namingMode == .immediate
            showsNamingField = namingToggleVisible && settings.askNameForEachStep
            naming = StepNaming(session: session, enabled: showsNamingField)

            let monitor = ClickMonitor(targetWindowID: window.id) { [weak self] point, bounds in
                self?.handleClick(at: point, windowBounds: bounds)
            }
            monitor.start()
            clickMonitor = monitor

            phase = .recording
        } catch {
            errorMessage = "Не удалось создать папку для отчёта. Проверьте путь в настройках."
            phase = .pickingWindow
        }
    }

    func openScreenRecordingSettings() {
        Permissions.openScreenRecordingSettings()
    }

    // MARK: - Запись

    private func handleClick(at point: CGPoint, windowBounds: CGRect) {
        guard phase == .recording, let session else { return }

        // Набранное название относится к предыдущему шагу — закрепляем его до создания нового.
        if showsNamingField {
            naming?.clickRecorded()
        }

        session.noteClick(at: point, windowBounds: windowBounds)
        stepCount = session.steps.count

        Task { @MainActor in
            await session.waitForPendingCaptures()
            refreshFromSession()

            if session.consecutiveWindowNotFoundCount >= windowNotFoundLimit {
                stopBecauseTargetWindowClosed()
            }
        }
    }

    func stopRecording() {
        stop(reason: .stoppedByUser)
    }

    private func stopBecauseTargetWindowClosed() {
        stop(reason: .targetWindowClosed)
    }

    private func stop(reason: StopReason) {
        clickMonitor?.stop()
        clickMonitor = nil
        stopReason = reason

        guard let session else {
            phase = .idle
            return
        }

        Task { @MainActor in
            await session.waitForPendingCaptures()
            refreshFromSession()

            // В режиме «потом» сначала даём подписать шаги. Если окно закрылось — сохраняем
            // сразу, чтобы человек не остался без отчёта.
            if settingsStore.current.namingMode == .afterStop, reason == .stoppedByUser {
                prepareStepList()
                pendingStepList = true
            } else {
                _ = saveReport()
            }

            phase = .finished
        }
    }

    func setAskNameForEachStep(_ value: Bool) {
        askNameForEachStep = value

        var settings = settingsStore.current
        settings.askNameForEachStep = value
        settingsStore.update(settings)

        showsNamingField = settings.namingMode == .immediate && value
        naming?.isEnabled = showsNamingField

        // Поле названия появилось или исчезло — панели нужно подстроить высоту.
        onHUDNeedsResize?()
    }

    func prepareStepList() {
        guard let session else { return }
        stepNames = Dictionary(uniqueKeysWithValues: session.steps.map { ($0.index, $0.name) })
    }

    func saveFromStepList() {
        if let session {
            for (index, name) in stepNames {
                session.nameStep(at: index, with: name)
            }
        }
        _ = saveReport()
        pendingStepList = false
    }

    func saveWithoutNames() {
        _ = saveReport()
        pendingStepList = false
    }

    func reset() {
        clickMonitor?.stop()
        clickMonitor = nil
        session = nil
        naming = nil
        scenarioName = ""
        selectedWindow = nil
        stepCount = 0
        latestImage = nil
        lastReportURL = nil
        errorMessage = nil
        stopReason = .stoppedByUser
        pendingStepList = false
        stepNames = [:]
        phase = .idle
    }

    @discardableResult
    func saveReport() -> Bool {
        guard let session else { return false }

        let steps = session.steps.map { step in
            ReportStep(
                index: step.index,
                name: step.name,
                image: session.images[step.index],
                pointNormalized: step.pointNormalized,
                errorText: step.errorText
            )
        }

        let url = session.folder.appendingPathComponent(StepFileNames.reportFileName)
        var options = PDFRenderer.Options()
        options.markClickPoint = settingsStore.current.markClickPoint

        do {
            try PDFRenderer.render(
                scenarioName: session.scenarioName,
                startedAt: session.startedAt,
                steps: steps,
                setup: .a4,
                options: options,
                to: url
            )
            lastReportURL = url
            return true
        } catch {
            errorMessage = "Не удалось сохранить отчёт"
            return false
        }
    }

    func openReport() {
        guard let lastReportURL else { return }
        NSWorkspace.shared.open(lastReportURL)
    }

    func revealReportInFinder() {
        guard let lastReportURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastReportURL])
    }

    private func refreshFromSession() {
        guard let session else { return }
        stepCount = session.steps.count
        latestImage = session.latestIndex.flatMap { session.images[$0] }
    }
}
