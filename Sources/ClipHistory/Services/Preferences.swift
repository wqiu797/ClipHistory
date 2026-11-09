import Foundation

/// Centralised user defaults so keys and fallbacks are defined once.
enum Preferences {
    static let retentionDaysKey = "retentionDays"
    static let defaultRetentionDays = 3
    static let isCapturePausedKey = "isCapturePaused"

    static var retentionDays: Int {
        get {
            let days = UserDefaults.standard.integer(forKey: retentionDaysKey)
            return days > 0 ? days : defaultRetentionDays
        }
        set {
            UserDefaults.standard.set(newValue, forKey: retentionDaysKey)
        }
    }

    static var isCapturePaused: Bool {
        get { UserDefaults.standard.bool(forKey: isCapturePausedKey) }
        set { UserDefaults.standard.set(newValue, forKey: isCapturePausedKey) }
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            retentionDaysKey: defaultRetentionDays,
            isCapturePausedKey: false,
        ])
    }
}
