import AppKit
import StepSnapCore
import SwiftUI

struct MenuContentView: View {
    let store: SettingsStore
    let onPickWindow: (WindowInfo) -> Void
    let onRequestClose: () -> Void

    @State private var showsSettings = false
    @State private var showsWindowPicker = false
    @State private var pickedWindow: WindowInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSettings {
                SettingsView(store: store)
                Button("Готово") { showsSettings = false }
            } else if showsWindowPicker {
                WindowPickerView { window in
                    pickedWindow = window
                    showsWindowPicker = false
                    onPickWindow(window)
                    onRequestClose()
                }
                Button("Отмена") { showsWindowPicker = false }
            } else {
                Text("StepSnap")
                    .font(.headline)

                if let pickedWindow {
                    Text("Выбрано: \(pickedWindow.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack {
                    Button("Выбрать окно") { showsWindowPicker = true }
                    Button("Настройки") { showsSettings = true }
                    Button("Выход") { NSApplication.shared.terminate(nil) }
                }
            }
        }
        .padding(16)
        .frame(width: showsSettings ? 360 : 320, alignment: .leading)
    }
}
