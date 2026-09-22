import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager
    #if os(iOS)
    @State private var showLaunchHandoff = true
    #endif

    var body: some View {
        ZStack {
            Group {
                if !authManager.isSignedIn {
                    WelcomeView()
                } else if !authManager.hasCompletedOnboarding {
                    OnboardingFlowView()
                } else {
                    BirthdayListView()
                }
            }

            #if os(iOS)
            if showLaunchHandoff && !authManager.isSignedIn {
                LaunchHandoffView {
                    showLaunchHandoff = false
                }
                .zIndex(1)
            }
            #endif
        }
    }
}

#if os(iOS)
/// Continues the static launch screen, then opens the gift into Welcome.
private struct LaunchHandoffView: View {
    var onFinished: () -> Void

    @State private var giftScale: CGFloat = 1
    @State private var giftOpacity: Double = 1
    @State private var backdropOpacity: Double = 1

    var body: some View {
        ZStack {
            RememberColors.brandBlue
                .ignoresSafeArea()
                .opacity(backdropOpacity)

            Image("BrandGift")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(giftScale)
                .opacity(giftOpacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            // ~1.5s brand mark, then open into Welcome.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                    giftScale = 1.55
                }
                withAnimation(.easeInOut(duration: 0.45)) {
                    giftOpacity = 0
                    backdropOpacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onFinished()
            }
        }
    }
}
#endif
