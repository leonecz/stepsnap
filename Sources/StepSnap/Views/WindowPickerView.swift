import StepSnapCore
import SwiftUI

struct WindowPickerView: View {
    let onPick: (WindowInfo) -> Void

    @State private var windows: [WindowInfo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Выберите окно")
                    .font(.headline)
                Spacer(minLength: 8)
                Button("Обновить") { refresh() }
            }

            if windows.isEmpty {
                Text("Не найдено ни одного подходящего окна")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(windows, id: \.id) { window in
                            Button {
                                onPick(window)
                            } label: {
                                Text(window.label)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 240)
            }
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        windows = WindowEnumerator.capturableWindows()
    }
}
