import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class SettingsViewModel {
    var retentionDays: Int {
        didSet {
            UserDefaults.standard.set(retentionDays, forKey: "retentionDays")
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
        let days = UserDefaults.standard.integer(forKey: "retentionDays")
        retentionDays = days > 0 ? days : 3
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
