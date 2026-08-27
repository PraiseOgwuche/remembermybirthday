import Foundation

extension AppSettingsStore {
    private static let emailKey = "settings.notificationEmail"
    private static let emailAccountKey = "settings.emailAccountEvents"
    private static let emailReminderKey = "settings.emailBirthdayReminders"

    /// Optional address for welcome / sign-in / birthday emails (requires backend).
    static var notificationEmail: String {
        get { UserDefaults.standard.string(forKey: emailKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: emailKey) }
    }

    static var emailAccountEvents: Bool {
        get {
            if UserDefaults.standard.object(forKey: emailAccountKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: emailAccountKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: emailAccountKey) }
    }

    static var emailBirthdayReminders: Bool {
        get {
            if UserDefaults.standard.object(forKey: emailReminderKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: emailReminderKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: emailReminderKey) }
    }
}
