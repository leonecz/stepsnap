import AppKit
import StepSnapCore
import SwiftUI

struct MenuContentView: View {
    let store: SettingsStore
    @State private var showsSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSettings {
                SettingsView(store: store)
                Button("Готово") { showsSettings = false }
            } else {
                Text("StepSnap")
                    .font(.headline)

                HStack {
                    Button("Настройки") { showsSettings = true }
                    Button("Выход") { NSApplication.shared.terminate(nil) }
                }
            }
        }
        .padding(16)
        .frame(width: showsSettings ? 360 : 320, alignment: .leading)
    }
}
