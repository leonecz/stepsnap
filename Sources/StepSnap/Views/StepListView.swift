import StepSnapCore
import SwiftUI
import UniformTypeIdentifiers

/// Подпись шагов списком — финальный экран после «Стоп».
struct StepListView: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Подпишите шаги")
                .font(.headline)

            Text("\(appState.stepNames.count) шагов. Можно подписать и приложить ожидаемый результат.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(appState.stepNames.keys.sorted(), id: \.self) { index in
                        HStack(spacing: 8) {
                            Text("\(index).")
                                .monospacedDigit()
                                .frame(width: 24, alignment: .trailing)

                            if let image = appState.session?.images[index] {
                                Image(decorative: image, scale: 1)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }

                            TextField("Название шага", text: Binding(
                                get: { appState.stepNames[index] ?? "" },
                                set: { appState.stepNames[index] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)

                            expectedResultControl(for: index)

                            if index == appState.lastStepIndex {
                                Button {
                                    appState.deleteLastStep()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Удалить последний шаг")
                            }
                        }
                        // Эталон можно перетащить прямо на строку своего шага.
                        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
                            ExpectedResultDrop.loadImage(from: providers) { image in
                                appState.attachExpectedResult(image, toStep: index)
                            }
                        }
                    }
                }
            }
            .frame(height: 280)

            HStack {
                Button("Сохранить PDF") { appState.saveFromStepList() }
                Button("Без названий") { appState.saveWithoutNames() }
            }
        }
    }

    /// Приложенный эталон сам служит кнопкой: нажатие открывает выбор файла.
    @ViewBuilder
    private func expectedResultControl(for index: Int) -> some View {
        if let image = appState.expectedImage(forStep: index) {
            HStack(spacing: 2) {
                Button {
                    appState.chooseExpectedResult(forStep: index)
                } label: {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color.accentColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.borderless)
                .help("Ожидаемый результат. Нажмите, чтобы заменить")

                Button {
                    appState.removeExpectedResult(fromStep: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Убрать ожидаемый результат")
            }
        } else {
            Button {
                appState.chooseExpectedResult(forStep: index)
            } label: {
                Image(systemName: "photo.badge.plus")
            }
            .buttonStyle(.borderless)
            .help("Приложить ожидаемый результат")
        }
    }
}
