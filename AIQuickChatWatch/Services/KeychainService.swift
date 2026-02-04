import Foundation
import Security

/// Service for secure token storage using iOS Keychain
actor KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.aiquickchat.watch"

    private enum Keys {
        static let authToken = "auth_token"
        static let userEmail = "user_email"
        static let geminiAPIKey = "gemini_api_key"
    }

    private init() {}

    // MARK: - Auth Token

    func saveAuthToken(_ token: String) throws {
        try save(key: Keys.authToken, value: token)
    }

    func getAuthToken() -> String? {
        get(key: Keys.authToken)
    }

    func deleteAuthToken() throws {
        try delete(key: Keys.authToken)
    }

    // MARK: - User Email

    func saveUserEmail(_ email: String) throws {
        try save(key: Keys.userEmail, value: email)
    }

    func getUserEmail() -> String? {
        get(key: Keys.userEmail)
    }

    func deleteUserEmail() throws {
        try delete(key: Keys.userEmail)
    }

    // MARK: - Gemini API Key

    func saveGeminiAPIKey(_ key: String) throws {
        try save(key: Keys.geminiAPIKey, value: key)
    }

    func getGeminiAPIKey() -> String? {
        get(key: Keys.geminiAPIKey)
    }

    // MARK: - Clear All

    func clearAll() throws {
        try delete(key: Keys.authToken)
        try delete(key: Keys.userEmail)
    }

    // MARK: - Private Helpers

    private func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Errors

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value for Keychain"
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        }
    }
}
