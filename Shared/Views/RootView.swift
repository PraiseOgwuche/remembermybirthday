import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Group {
            if !authManager.isSignedIn {
                WelcomeView()
            } else if !authManager.hasCompletedOnboarding {
                OnboardingFlowView()
            } else {
                BirthdayListView()
            }
        }
    }
}
