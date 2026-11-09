import SwiftUI
import KeyboardShortcuts

@main
struct ClipHistoryApp: App {
    @NSApplicationDelegateAdaptor(StatusBarController.self) var appDelegate

    init() {
        Preferences.registerDefaults()

        // Global keyboard shortcut
        KeyboardShortcuts.onKeyDown(for: .showClipHistory) {
            StatusBarController.shared?.showPopover()
        }
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
