import SwiftUI
import SwiftData

@main
struct RememberWatchApp: App {
    private let container = RememberDataStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .tint(Color(red: 0.20, green: 0.45, blue: 0.85))
        }
        .modelContainer(container)
    }
}
