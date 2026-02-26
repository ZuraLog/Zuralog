/// KeychainHelper — Shared Keychain access for background sync credentials.
///
/// Persists the JWT auth token and Cloud Brain API base URL into the iOS
/// Keychain so that native background sync code (running outside the
/// Flutter engine in HKObserverQuery callbacks) can authenticate
/// directly with the Cloud Brain without waiting for Dart to be available.
///
/// Written by the Dart side via the `configureBackgroundSync` MethodChannel
/// call during Apple Health connection setup.

import Foundation
import Security

/// Thread-safe Keychain read/write for background sync credentials.
///
/// All values are stored under the service identifier `com.zuralog.backgroundSync`
/// so they are isolated from any other Keychain data the app may use.
class KeychainHelper {

    /// Shared singleton instance.
    static let shared = KeychainHelper()

    private let service = "com.zuralog.backgroundSync"

    private init() {}

    // MARK: - Write

    /// Saves a string value to the Keychain, replacing any existing value.
    ///
    /// - Parameters:
    ///   - key: The account key under which to store the value.
    ///   - value: The UTF-8 string to persist.
    /// - Returns: `true` if the save succeeded, `false` otherwise.
    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing entry before adding the new one to avoid duplication.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Only accessible when device is unlocked — background delivery
            // fires while the device may be locked, but HKObserverQuery
            // callbacks happen on the app's process, not in an extension,
            // so kSecAttrAccessibleAfterFirstUnlock is appropriate here.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("[KeychainHelper] Failed to save '\(key)': OSStatus \(status)")
        }
        return status == errSecSuccess
    }

    // MARK: - Read

    /// Reads a string value from the Keychain.
    ///
    /// - Parameter key: The account key to look up.
    /// - Returns: The stored string, or `nil` if not found or on error.
    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    /// Removes a stored value from the Keychain.
    ///
    /// - Parameter key: The account key to remove.
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
