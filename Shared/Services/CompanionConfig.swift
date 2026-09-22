import Foundation

/// Ship-time companion config.
enum CompanionConfig {
    static let productionBackendURL = "https://remember-companion.onrender.com"

    /// Host `landing/` on this domain (Cloudflare Pages / GitHub Pages custom domain).
    static let siteBaseURL = URL(string: "https://remembermybirthday.me")!

    static let privacyPolicyURL = URL(string: "https://remembermybirthday.me/privacy.html")
    static let termsOfUseURL = URL(string: "https://remembermybirthday.me/terms.html")
    static let supportURL = URL(string: "https://remembermybirthday.me/")
    static let supportEmail = "hello@remembermybirthday.me"

    static var resolvedBackendURL: String {
        let override = AppSettingsStore.companionBackendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty { return override }
        return productionBackendURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
