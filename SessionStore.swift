import Foundation
import Security

final class SessionStore: ObservableObject {
    // Keep this in sync with PRODUCT_BUNDLE_IDENTIFIER in project.yml.
    private let service = "com.example.claudeusage"
    private let account = "claude-session-key"

    @Published var sessionKey: String? {
        didSet { persist(sessionKey) }
    }

    init() {
        self.sessionKey = load()
    }

    private func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private func persist(_ value: String?) {
        let delete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(delete as CFDictionary)

        guard let value = value, !value.isEmpty,
              let data = value.data(using: .utf8) else { return }

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(add as CFDictionary, nil)
    }
}
