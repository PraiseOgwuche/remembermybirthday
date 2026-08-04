import SwiftUI
import SwiftData

@main
struct RememberMacApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var notificationScheduler = NotificationScheduler()

    private let container = RememberDataStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(notificationScheduler)
                .environmentObject(MessageDeepLinkRouter.shared)
                .tint(Color(red: 0.20, green: 0.45, blue: 0.85))
                .frame(minWidth: 520, minHeight: 560)
                .onAppear {
                    notificationScheduler.configure()
                }
        }
        .modelContainer(container)
        .defaultSize(width: 720, height: 640)
    }
}
