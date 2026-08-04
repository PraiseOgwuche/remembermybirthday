import Foundation
import SwiftData

enum RememberDataStore {
    static let appGroupID = "group.com.remembermybirthday.app"
    static let storeName = "Remember"
    static let iCloudContainerID = "iCloud.com.remembermybirthday.app"

    static func makeContainer() -> ModelContainer {
        let schema = Schema([BirthdayPerson.self])

        #if os(watchOS)
        if isAppGroupAvailable,
           let container = makeGroupContainer(schema: schema, cloudKit: false) {
            return container
        }
        return makeLocalContainer(schema: schema)
        #else
        if isAppGroupAvailable {
            if let container = makeGroupContainer(schema: schema, cloudKit: AppSettingsStore.iCloudSyncEnabled) {
                return container
            }
        }

        if AppSettingsStore.iCloudSyncEnabled,
           AppSettingsStore.hasICloudAccount,
           let container = makeCloudOnlyContainer(schema: schema) {
            return container
        }

        return makeLocalContainer(schema: schema)
        #endif
    }

    private static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    private static func makeGroupContainer(schema: Schema, cloudKit: Bool) -> ModelContainer? {
        let config: ModelConfiguration
        if cloudKit, AppSettingsStore.hasICloudAccount {
            config = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private(iCloudContainerID)
            )
        } else {
            config = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .none
            )
        }
        return try? ModelContainer(for: schema, configurations: [config])
    }

    private static func makeCloudOnlyContainer(schema: Schema) -> ModelContainer? {
        let config = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(iCloudContainerID)
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    private static func makeLocalContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
