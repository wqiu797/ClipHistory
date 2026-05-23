import SwiftUI
import KeyboardShortcuts

@main
struct ClipHistoryApp: App {
    @NSApplicationDelegateAdaptor(StatusBarController.self) var appDelegate

    init() {
        // Set default retention days
        if UserDefaults.standard.integer(forKey: "retentionDays") == 0 {
            UserDefaults.standard.set(3, forKey: "retentionDays")
        }

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
