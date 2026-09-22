import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var userName: String?
    @Published private(set) var userIdentifier: String?
    @Published private(set) var userEmail: String?
    @Published var hasCompletedOnboarding: Bool
    /// User-facing explanation when Sign in with Apple fails (e.g. error 1000).
    @Published var signInMessage: String?

    private let signedInKey = "remember.isSignedIn"
    private let nameKey = "remember.userName"
    private let idKey = "remember.userIdentifier"
    private let onboardingKey = "remember.hasCompletedOnboarding"
    private let emailKey = "remember.userEmail"

    init() {
        let defaults = UserDefaults.standard
        self.isSignedIn = defaults.bool(forKey: signedInKey)
        self.userName = defaults.string(forKey: nameKey)
        self.userIdentifier = defaults.string(forKey: idKey)
        self.hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
        let storedEmail = defaults.string(forKey: emailKey)
        self.userEmail = storedEmail
        syncNotificationEmail(from: storedEmail)
    }

    var hasEmailForNotifications: Bool {
        let value = (userEmail ?? AppSettingsStore.notificationEmail)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("@") && value.contains(".")
    }

    func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            let defaults = UserDefaults.standard
            let identifier = credential.user
            defaults.set(identifier, forKey: idKey)
            defaults.set(true, forKey: signedInKey)

            if let fullName = credential.fullName {
                let formatted = PersonNameComponentsFormatter().string(from: fullName)
                if !formatted.isEmpty {
                    defaults.set(formatted, forKey: nameKey)
                    userName = formatted
                }
            }

            // Apple returns email only on the first authorization (may be a private relay).
            if let email = credential.email, !email.isEmpty {
                saveEmail(email)
            } else if userEmail == nil,
                      let existing = defaults.string(forKey: emailKey), !existing.isEmpty {
                userEmail = existing
                syncNotificationEmail(from: existing)
            }

            userIdentifier = identifier
            isSignedIn = true
            signInMessage = nil

            sendAccountEmailIfPossible()

        case .failure(let error):
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    return
                case .unknown:
                    signInMessage = """
                    Sign in with Apple isn’t fully enabled for this app yet.

                    In Xcode → Signing & Capabilities, click + and add “Sign in with Apple” \
                    (it should appear under Capabilities). Then run again.

                    Or tap Continue without account — your birthdays still save on this iPhone.
                    """
                default:
                    signInMessage = authError.localizedDescription
                }
            } else {
                signInMessage = error.localizedDescription
            }
        }
    }

    /// Manual fallback when Apple doesn’t return an email (rare after first SIWA).
    func saveEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else { return }
        UserDefaults.standard.set(trimmed, forKey: emailKey)
        userEmail = trimmed
        syncNotificationEmail(from: trimmed)
    }

    func continueWithoutAccount() {
        UserDefaults.standard.set(true, forKey: signedInKey)
        isSignedIn = true
        signInMessage = nil
        if userName == nil {
            userName = "Friend"
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        hasCompletedOnboarding = true
    }

    /// Clears session + onboarding so you can re-test the full first-run flow.
    func resetForFreshLaunch() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: signedInKey)
        defaults.set(false, forKey: onboardingKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: idKey)
        defaults.removeObject(forKey: emailKey)
        defaults.removeObject(forKey: "remember.sentWelcomeEmail")
        isSignedIn = false
        hasCompletedOnboarding = false
        userName = nil
        userIdentifier = nil
        userEmail = nil
        signInMessage = nil
        AppSettingsStore.notificationEmail = ""
    }

    func signOut() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: signedInKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: idKey)
        // Keep emailKey so returning SIWA users still get reminders without re-entry.
        isSignedIn = false
        userName = nil
        userIdentifier = nil
    }

    func deleteAccountOnDevice() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: signedInKey)
        defaults.set(false, forKey: onboardingKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: idKey)
        defaults.removeObject(forKey: emailKey)
        defaults.removeObject(forKey: "remember.sentWelcomeEmail")
        isSignedIn = false
        hasCompletedOnboarding = false
        userName = nil
        userIdentifier = nil
        userEmail = nil
        signInMessage = nil
        AppSettingsStore.notificationEmail = ""
    }

    private func syncNotificationEmail(from email: String?) {
        guard let email, !email.isEmpty else { return }
        AppSettingsStore.notificationEmail = email
    }

    private func sendAccountEmailIfPossible() {
        guard hasEmailForNotifications else { return }
        let defaults = UserDefaults.standard
        let welcomeKey = "remember.sentWelcomeEmail"
        if !defaults.bool(forKey: welcomeKey) {
            EmailNotifier.sendAccountEvent(.welcome, name: userName)
            defaults.set(true, forKey: welcomeKey)
        } else {
            EmailNotifier.sendAccountEvent(.signIn, name: userName)
        }
    }
}
