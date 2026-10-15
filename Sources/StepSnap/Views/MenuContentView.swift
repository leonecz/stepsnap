import AppKit
import SwiftUI

struct MenuContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("StepSnap")
                .font(.headline)

            Button("Выход") { NSApplication.shared.terminate(nil) }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
