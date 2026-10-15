import StepSnapCore
import SwiftUI

/// Предложение дособрать отчёт по сценарию, который не завершили: манифест и снимки
/// на диске есть, PDF нет.
struct RecoveryView: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(appState.unfinishedScenarios, id: \.folder) { scenario in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Незавершённый сценарий: «\(scenario.manifest.scenarioName)», шагов: \(scenario.stepCount)")
                        .font(.callout)
                        .lineLimit(2)

                    HStack {
                        Button("Собрать PDF") { appState.recover(scenario) }
                        Button("Скрыть") { appState.dismiss(scenario) }
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
