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

    var loginItemError: String?

    var launchAtLogin: Bool {
        didSet {
            loginItemError = nil
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                    if SMAppService.mainApp.status != .enabled {
                        loginItemError = "Approve ClipHistory in System Settings > General > Login Items."
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.ui.error("Failed to toggle login item: \(String(describing: error), privacy: .public)")
                loginItemError = "Could not update the login item: \(error.localizedDescription)"
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    init() {
        retentionDays = Preferences.retentionDays
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
