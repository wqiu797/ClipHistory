import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class SettingsViewModel {
    var retentionDays: Int {
        didSet {
            Preferences.retentionDays = retentionDays
            CleanupScheduler.shared.performCleanup()
        }
    }

    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.ui.error("Failed to toggle login item: \(String(describing: error), privacy: .public)")
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    init() {
        retentionDays = Preferences.retentionDays
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
