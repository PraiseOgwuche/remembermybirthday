import Foundation

enum CompanionAIProvider: String, CaseIterable, Identifiable {
    case auto
    case apple
    case anthropic
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto (on-device, then server)"
        case .apple: return "On-device only"
        case .anthropic: return "Server only"
        case .off: return "Off — local tips only"
        }
    }
}

extension AppSettingsStore {
    private static let aiEnabledKey = "settings.aiEnabled"
    private static let aiProviderKey = "settings.aiProvider"
    private static let backendURLKey = "settings.companionBackendURL"

    static var aiEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: aiEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: aiEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: aiEnabledKey) }
    }

    static var aiProvider: CompanionAIProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: aiProviderKey) ?? ""
            return CompanionAIProvider(rawValue: raw) ?? .auto
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: aiProviderKey) }
    }

    static var companionBackendURL: String {
        get { UserDefaults.standard.string(forKey: backendURLKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: backendURLKey) }
    }
}
