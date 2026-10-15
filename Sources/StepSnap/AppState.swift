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

    /// Запись на паузе: клики в эмуляторе в отчёт не идут.
    var isPaused = false {
        didSet {
            if isPaused != oldValue {
                onPauseChanged?()
            }
        }
    }

    var onPauseChanged: (() -> Void)?

    /// Режим «потом»: после остановки сначала подписываем шаги, потом сохраняем.
    var pendingStepList = false
    var stepNames: [Int: String] = [:]

    /// Найденные при запуске незавершённые сценарии.
    var unfinishedScenarios: [UnfinishedScenario] = []

    /// AppKit-обвязка подписывается сюда: показать HUD, закрыть поповер, сменить иконку.
    var onPhaseChanged: ((Phase) -> Void)?

    private let frameSource = ScreenCaptureFrameSource()
    private var clickMonitor: ClickMonitor?
    private var watchdogTimer: Timer?

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
            // Запрос нужен не ради диалога, а чтобы система добавила приложение
            // в список «Запись экрана»: без этого его там просто нет и выдать нечего.
            Permissions.requestScreenRecording()
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
            isPaused = false

            askNameForEachStep = settings.askNameForEachStep
            namingToggleVisible = settings.namingMode == .immediate
            showsNamingField = namingToggleVisible && settings.askNameForEachStep
            naming = StepNaming(session: session, enabled: showsNamingField)

            let monitor = ClickMonitor(targetWindowID: window.id) { [weak self] point, bounds in
                self?.handleClick(at: point, windowBounds: bounds)
            }
            monitor.start()
            clickMonitor = monitor

            startWatchdog()

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
        // На паузе клик не делает ничего — даже поле названия не трогаем.
        guard !session.isPaused else { return }

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

    /// Пауза: клики в эмуляторе перестают попадать в отчёт, всё собранное остаётся.
    func togglePause() {
        guard phase == .recording, let session else { return }

        if !session.isPaused, showsNamingField {
            // На паузе кликов не будет, и закрепить набранное станет нечему — делаем это сейчас.
            naming?.commitFieldText()
        }

        session.isPaused.toggle()
        isPaused = session.isPaused
    }

    private func stopBecauseTargetWindowClosed() {
        stop(reason: .targetWindowClosed)
    }

    private func stop(reason: StopReason) {
        // Кнопок «Стоп» две (панель записи и поповер), плюс сюда же приходит сторож:
        // без этой проверки отчёт мог бы собираться дважды и одновременно.
        guard phase == .recording else { return }

        stopWatchdog()
        clickMonitor?.stop()
        clickMonitor = nil
        stopReason = reason

        guard let session else {
            phase = .idle
            return
        }

        // Название, набранное для последнего шага, иначе потерялось бы: закрепить его
        // обычно успевает только следующий клик, а после «Стоп» кликов уже не будет.
        if showsNamingField {
            naming?.commitFieldText()
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

    func setAskNameForEachStep(_ value: Bool) {        askNameForEachStep = value

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

    // MARK: - Восстановление

    func scanForUnfinished() {
        unfinishedScenarios = RecoveryScan.unfinished(in: settingsStore.current.outputFolder)
    }

    func recover(_ scenario: UnfinishedScenario) {
        let steps = ReportSteps.from(manifest: scenario.manifest, folder: scenario.folder)

        var options = PDFRenderer.Options()
        options.markClickPoint = settingsStore.current.markClickPoint

        let url = scenario.folder.appendingPathComponent(StepFileNames.reportFileName)

        do {
            try PDFRenderer.render(
                scenarioName: scenario.manifest.scenarioName,
                startedAt: scenario.manifest.startedAt,
                steps: steps,
                setup: .a4,
                options: options,
                to: url
            )
            lastReportURL = url
            stepCount = steps.count
            stopReason = .stoppedByUser
            unfinishedScenarios.removeAll { $0.folder == scenario.folder }
            phase = .finished
        } catch {
            errorMessage = "Не удалось собрать отчёт"
        }
    }

    func dismiss(_ scenario: UnfinishedScenario) {
        unfinishedScenarios.removeAll { $0.folder == scenario.folder }
    }

    func reset() {
        stopWatchdog()
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
        isPaused = false
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

    // MARK: - Сторож целевого окна

    private func startWatchdog() {
        stopWatchdog()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkTargetWindow()
            }
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    /// Раз в секунду проверяем, что целевое окно ещё существует: без этого закрытое
    /// окно осталось бы незамеченным, потому что кликов в него больше не происходит.
    private func checkTargetWindow() {
        guard phase == .recording, let session else { return }

        let shouldStop = RecordingWatchdog.shouldStop(
            windowID: session.windowID,
            windows: WindowEnumerator.allWindows(),
            consecutiveWindowNotFoundCount: session.consecutiveWindowNotFoundCount
        )

        if shouldStop {
            stopBecauseTargetWindowClosed()
        }
    }
}
