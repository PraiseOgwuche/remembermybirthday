import Foundation
import Security

enum AISecrets {
    private static let service = "com.remembermybirthday.app"
    private static let account = "anthropicAPIKey"

    static var anthropicAPIKey: String? {
        get { readKeychain() ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] }
        set {
            if let newValue, !newValue.isEmpty {
                saveKeychain(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                deleteKeychain()
            }
        }
    }

    static var hasAnthropicKey: Bool {
        !(anthropicAPIKey ?? "").isEmpty
    }

    private static func saveKeychain(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
