import StepSnapCore
import SwiftUI

/// Подпись шагов списком — режим «потом».
struct StepListView: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Подпишите шаги")
                .font(.headline)

            Text("\(appState.stepNames.count) шагов. Название можно оставить пустым.")
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
                        }
                    }
                }
            }
            .frame(height: 240)

            HStack {
                Button("Сохранить PDF") { appState.saveFromStepList() }
                Button("Без названий") { appState.saveWithoutNames() }
            }
        }
    }
}
