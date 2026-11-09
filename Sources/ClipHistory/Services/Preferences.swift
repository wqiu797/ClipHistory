import Foundation

/// Centralised user defaults so keys and fallbacks are defined once.
enum Preferences {
    static let retentionDaysKey = "retentionDays"
    static let defaultRetentionDays = 3

    static var retentionDays: Int {
        get {
            let days = UserDefaults.standard.integer(forKey: retentionDaysKey)
            return days > 0 ? days : defaultRetentionDays
        }
        set {
            UserDefaults.standard.set(newValue, forKey: retentionDaysKey)
        }
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [retentionDaysKey: defaultRetentionDays])
    }
}
