import SwiftUI
import SwiftData
import UserNotifications

@main
struct RememberApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(RememberAppDelegate.self) private var appDelegate
    #endif

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
                .onAppear {
                    notificationScheduler.configure()
                }
                .onOpenURL { url in
                    MessageDeepLinkRouter.shared.handle(url: url)
                }
        }
        .modelContainer(container)
    }
}

#if os(iOS)
final class RememberAppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = ReminderNotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}
#endif
