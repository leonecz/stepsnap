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

            if let image = appState.latestImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Button("Стоп") {
                appState.stopRecording()
            }
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
    }
}
