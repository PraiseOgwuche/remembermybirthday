import Foundation

/// Contact prompt dismiss / known-id persistence.
enum ContactBirthdayPromptStore {
    private static let knownKey = "contactPrompt.knownIds"
    private static let dismissedKey = "contactPrompt.dismissedIds"
    private static let lastActiveKey = "contactPrompt.lastActiveAt"
    private static let lastPromptKey = "contactPrompt.lastPromptAt"
    private static let lastPromptContactKey = "contactPrompt.lastPromptContactId"

    static var knownContactIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: knownKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: knownKey) }
    }

    static var dismissedContactIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: dismissedKey) }
    }

    static var lastActiveAt: Date? {
        get { UserDefaults.standard.object(forKey: lastActiveKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastActiveKey) }
    }

    static var lastPromptAt: Date? {
        get { UserDefaults.standard.object(forKey: lastPromptKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastPromptKey) }
    }

    static var lastPromptContactId: String? {
        get { UserDefaults.standard.string(forKey: lastPromptContactKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastPromptContactKey) }
    }

    static func dismiss(contactId: String) {
        var ids = dismissedContactIds
        ids.insert(contactId)
        dismissedContactIds = ids
        lastPromptAt = Date()
        lastPromptContactId = contactId
    }

    static func markPrompted(contactId: String) {
        lastPromptAt = Date()
        lastPromptContactId = contactId
    }

    static func markActive() {
        lastActiveAt = Date()
    }
}
