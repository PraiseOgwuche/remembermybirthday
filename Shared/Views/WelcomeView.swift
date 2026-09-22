import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    private let buttonHeight: CGFloat = 54
    private let buttonCorner: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)

            VStack(spacing: 24) {
                #if os(iOS)
                Image("BrandGift")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .padding(22)
                    .background(RememberColors.brandBlue, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityHidden(true)
                #else
                Image(systemName: "gift.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .padding(22)
                    .background(RememberColors.brandBlue, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityHidden(true)
                #endif

                VStack(spacing: 10) {
                    Text("Remember My Birthday")
                        .font(.system(.largeTitle, design: .default).weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Never miss someone who matters.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Sync Contacts, get early reminders, and open Messages with a draft ready.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleSignIn(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
                .clipShape(RoundedRectangle(cornerRadius: buttonCorner, style: .continuous))

                Button {
                    authManager.continueWithoutAccount()
                } label: {
                    Text("Continue without account")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: buttonHeight)
                        .background(
                            RememberColors.cardBackground,
                            in: RoundedRectangle(cornerRadius: buttonCorner, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: buttonCorner, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Text("Sign in with Apple for welcome + reminder emails. Or continue on this iPhone only.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RememberColors.elevatedBackground.ignoresSafeArea())
        .alert(
            "Sign in with Apple",
            isPresented: Binding(
                get: { authManager.signInMessage != nil },
                set: { if !$0 { authManager.signInMessage = nil } }
            )
        ) {
            Button("Continue without account") {
                authManager.continueWithoutAccount()
            }
            Button("OK", role: .cancel) {
                authManager.signInMessage = nil
            }
        } message: {
            Text(authManager.signInMessage ?? "")
        }
    }
}
