import Foundation

/// Ship-time companion config. Put your HTTPS Render/Fly URL here before App Store archive.
enum CompanionConfig {
    /// Production backend (must be HTTPS). Leave empty until deployed — local tips still work.
    /// Example: "https://remember-companion.onrender.com"
    static let productionBackendURL = ""

    /// Privacy policy hosted with the landing site (required in App Store Connect).
    static let privacyPolicyURL = URL(string: "https://praiseogwuche.github.io/remembermybirthday/privacy.html")
    static let supportURL = URL(string: "https://praiseogwuche.github.io/remembermybirthday/")

    static var resolvedBackendURL: String {
        let override = AppSettingsStore.companionBackendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty { return override }
        return productionBackendURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
