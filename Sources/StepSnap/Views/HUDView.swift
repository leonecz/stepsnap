import StepSnapCore
import SwiftUI

struct HUDView: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.session?.scenarioName ?? "Запись")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Text("Шагов: \(appState.stepCount)")
                .font(.callout)
                .monospacedDigit()

            // Строка состояния: заметный признак паузы и постоянная высота панели.
            Text(appState.isPaused ? "Пауза — клики не записываются" : "Идёт запись")
                .font(.caption)
                .foregroundStyle(appState.isPaused ? Color.orange : Color.secondary)

            if let image = appState.latestImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Чекбокс и поле названия — только для режима «сразу».
            // Чекбокс остаётся на виду, чтобы подпись можно было включить прямо во время записи.
            if appState.namingToggleVisible {
                Toggle("Давать название каждому шагу", isOn: Binding(
                    get: { appState.askNameForEachStep },
                    set: { appState.setAskNameForEachStep($0) }
                ))
                .toggleStyle(.checkbox)
                .font(.callout)

                if appState.showsNamingField {
                    TextField("Название шага", text: Binding(
                        get: { appState.naming?.fieldText ?? "" },
                        set: { appState.naming?.updateFieldText($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { appState.naming?.commitFieldText() }
                }
            }

            HStack {
                Button(appState.isPaused ? "Продолжить" : "Пауза") {
                    appState.togglePause()
                }
                Button("Стоп") {
                    appState.stopRecording()
                }
            }
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
    }
}
