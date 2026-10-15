import AppKit
import StepSnapCore
import SwiftUI

struct SettingsView: View {
    private let store: SettingsStore
    @State private var settings: StepSnapCore.Settings

    init(store: SettingsStore) {
        self.store = store
        _settings = State(initialValue: store.current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Настройки")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Папка сохранения")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(settings.outputFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(settings.outputFolder.path)
                    Spacer(minLength: 8)
                    Button("Изменить…") { chooseFolder() }
                }
            }

            Picker("Подпись шагов", selection: namingModeBinding) {
                Text("Сразу после клика").tag(NamingMode.immediate)
                Text("Потом, списком").tag(NamingMode.afterStop)
            }
            .pickerStyle(.menu)

            Toggle("Давать название каждому шагу", isOn: askNameBinding)

            Stepper(value: delayBinding, in: StepSnapCore.Settings.captureDelayRange, step: 50) {
                HStack {
                    Text("Задержка перед снимком")
                    Spacer(minLength: 8)
                    Text("\(settings.captureDelayMilliseconds) мс")
                        .monospacedDigit()
                }
            }

            Toggle("Отмечать точку клика", isOn: markClickPointBinding)
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
    }

    private var namingModeBinding: Binding<NamingMode> {
        Binding(
            get: { settings.namingMode },
            set: { settings.namingMode = $0; commit() }
        )
    }

    private var askNameBinding: Binding<Bool> {
        Binding(
            get: { settings.askNameForEachStep },
            set: { settings.askNameForEachStep = $0; commit() }
        )
    }

    private var delayBinding: Binding<Int> {
        Binding(
            get: { settings.captureDelayMilliseconds },
            set: { settings.captureDelayMilliseconds = $0; commit() }
        )
    }

    private var markClickPointBinding: Binding<Bool> {
        Binding(
            get: { settings.markClickPoint },
            set: { settings.markClickPoint = $0; commit() }
        )
    }

    private func commit() {
        store.update(settings)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Выбрать"
        panel.directoryURL = settings.outputFolder
        panel.message = "Куда складывать отчёты StepSnap"

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputFolder = url
            commit()
        }
    }
}
