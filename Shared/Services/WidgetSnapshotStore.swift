import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// App Group snapshot for WidgetKit.
struct WidgetPersonSnapshot: Codable, Hashable, Identifiable {
    var id: String
    var displayName: String
    var firstName: String
    var shortDate: String
    var daysUntil: Int
    var countdownLabel: String
    var draft: String
    var phone: String
    var birthMonth: Int
}

struct WidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var people: [WidgetPersonSnapshot]

    static let empty = WidgetSnapshot(updatedAt: .distantPast, people: [])
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.remembermybirthday.app"
    private static let key = "widget.upcomingSnapshot"

    static var suite: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> WidgetSnapshot {
        guard let data = suite?.data(forKey: key) else { return .empty }
        return (try? JSONDecoder().decode(WidgetSnapshot.self, from: data)) ?? .empty
    }

    static func saveSnapshot(_ snapshot: WidgetSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            suite?.set(data, forKey: key)
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
