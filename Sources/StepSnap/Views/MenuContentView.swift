import AppKit
import StepSnapCore
import SwiftUI

struct MenuContentView: View {
    let appState: AppState
    let onRequestClose: () -> Void

    @State private var showsSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSettings {
                SettingsView(store: appState.settingsStore)
                Button("Готово") { showsSettings = false }
            } else {
                content
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch appState.phase {
        case .idle:
            idleView
        case .naming:
            namingView
        case .pickingWindow:
            pickingWindowView
        case .recording:
            recordingView
        case .finished:
            finishedView
        }
    }

    // MARK: - Фазы

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("StepSnap")
                .font(.headline)

            HStack {
                Button("Новый сценарий") { appState.beginScenario() }
                Button("Настройки") { showsSettings = true }
                Button("Выход") { NSApplication.shared.terminate(nil) }
            }
        }
    }

    private var namingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Название сценария")
                .font(.headline)

            TextField("Например: Проверка входа", text: Binding(
                get: { appState.scenarioName },
                set: { appState.scenarioName = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .onSubmit { appState.confirmScenarioName() }

            HStack {
                Button("Продолжить") { appState.confirmScenarioName() }
                Button("Отмена") { appState.reset() }
            }
        }
    }

    private var pickingWindowView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сценарий: \(appState.scenarioName)")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)

                Button("Открыть настройки системы") { appState.openScreenRecordingSettings() }
            }

            WindowPickerView { window in
                appState.startRecording(window: window)
                if appState.phase == .recording {
                    onRequestClose()
                }
            }

            Button("Отмена") { appState.reset() }
        }
    }

    private var recordingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Идёт запись")
                .font(.headline)
            Text("Шагов: \(appState.stepCount)")
                .font(.callout)
                .monospacedDigit()
            Text("Управление записью — в панели сбоку.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Стоп") { appState.stopRecording() }
                Button("Скрыть") { onRequestClose() }
            }
        }
    }

    private var finishedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.stopReason == .targetWindowClosed ? "Окно закрылось" : "Отчёт готов")
                .font(.headline)

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let url = appState.lastReportURL {
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                HStack {
                    Button("Открыть PDF") { appState.openReport() }
                    Button("Показать в Finder") { appState.revealReportInFinder() }
                }
            } else {
                Text("Шагов записано: \(appState.stepCount)")
                    .font(.callout)
            }

            HStack {
                Button("Новый сценарий") { appState.reset() }
                Button("Выход") { NSApplication.shared.terminate(nil) }
            }
        }
    }
}
