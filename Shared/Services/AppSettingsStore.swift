import Foundation

enum AppSettingsStore {
    private static let reminderHourKey = "settings.reminderHour"
    private static let inactivityDaysKey = "settings.promptInactivityDays"
    private static let promptCooldownKey = "settings.promptCooldownDays"
    private static let nudgeDelayKey = "settings.promptNudgeDelayDays"
    private static let softEngageKey = "settings.softEngageEnabled"
    private static let iCloudSyncKey = "settings.iCloudSyncEnabled"

    static var reminderHour: Int {
        get {
            let value = UserDefaults.standard.object(forKey: reminderHourKey) as? Int
            return value ?? 9
        }
        set {
            UserDefaults.standard.set(min(23, max(0, newValue)), forKey: reminderHourKey)
        }
    }

    static var promptInactivityDays: Int {
        get { UserDefaults.standard.object(forKey: inactivityDaysKey) as? Int ?? 5 }
        set { UserDefaults.standard.set(max(1, newValue), forKey: inactivityDaysKey) }
    }

    static var promptCooldownDays: Int {
        get { UserDefaults.standard.object(forKey: promptCooldownKey) as? Int ?? 3 }
        set { UserDefaults.standard.set(max(1, newValue), forKey: promptCooldownKey) }
    }

    static var promptNudgeDelayDays: Int {
        get { UserDefaults.standard.object(forKey: nudgeDelayKey) as? Int ?? 7 }
        set { UserDefaults.standard.set(max(1, newValue), forKey: nudgeDelayKey) }
    }

    static var softEngageEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: softEngageKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: softEngageKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: softEngageKey) }
    }

    static var iCloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: iCloudSyncKey) }
        set { UserDefaults.standard.set(newValue, forKey: iCloudSyncKey) }
    }

    static var hasICloudAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private static let preferredWidgetSizeKey = "settings.preferredWidgetSize"
    private static let sawWidgetOnboardingKey = "settings.sawWidgetOnboarding"

    enum PreferredWidgetSize: String, CaseIterable, Identifiable {
        case small
        case medium
        case large

        var id: String { rawValue }

        var title: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            }
        }

        var detail: String {
            switch self {
            case .small: return "Name + countdown"
            case .medium: return "Draft + Send / Schedule"
            case .large: return "Draft + who’s coming up"
            }
        }
    }

    static var preferredWidgetSize: PreferredWidgetSize {
        get {
            let raw = UserDefaults.standard.string(forKey: preferredWidgetSizeKey) ?? ""
            return PreferredWidgetSize(rawValue: raw) ?? .medium
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferredWidgetSizeKey) }
    }

    static var sawWidgetOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: sawWidgetOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: sawWidgetOnboardingKey) }
    }
}
