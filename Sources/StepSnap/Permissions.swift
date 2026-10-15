import AppKit
import CoreGraphics

/// Разрешения системы, нужные StepSnap. Нужно одно — запись экрана.
enum Permissions {
    static func screenRecordingGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        let address = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }
}
