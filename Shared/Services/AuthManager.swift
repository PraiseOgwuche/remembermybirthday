import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var userName: String?
    @Published private(set) var userIdentifier: String?
    @Published var hasCompletedOnboarding: Bool
    /// User-facing explanation when Sign in with Apple fails (e.g. error 1000).
    @Published var signInMessage: String?

    private let signedInKey = "remember.isSignedIn"
    private let nameKey = "remember.userName"
    private let idKey = "remember.userIdentifier"
    private let onboardingKey = "remember.hasCompletedOnboarding"

    init() {
        let defaults = UserDefaults.standard
        self.isSignedIn = defaults.bool(forKey: signedInKey)
        self.userName = defaults.string(forKey: nameKey)
        self.userIdentifier = defaults.string(forKey: idKey)
        self.hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
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

            userIdentifier = identifier
            isSignedIn = true
            signInMessage = nil

        case .failure(let error):
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    return
                case .unknown:
                    // Error 1000 — client setup / provisioning, not a missing backend.
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
        isSignedIn = false
        hasCompletedOnboarding = false
        userName = nil
        userIdentifier = nil
        signInMessage = nil
    }

    func signOut() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: signedInKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: idKey)
        isSignedIn = false
        userName = nil
        userIdentifier = nil
    }
}
