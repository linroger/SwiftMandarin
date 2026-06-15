//
//  KeychainHelper.swift
//  SwiftMandarin
//
//  Lightweight, cross-platform (iOS/macOS) Keychain wrapper for storing
//  sensitive secrets such as cloud AI provider API keys. Uses a generic
//  password item keyed by an `account` string. Never stores secrets in
//  UserDefaults.
//

import Foundation
import Security

/// Secure storage for small secrets (API keys) backed by the system Keychain.
enum KeychainHelper {

    /// Service namespace for all SwiftMandarin secrets.
    private static let service = "linroger022.SwiftMandarin.secrets"

    /// Store (or update) a secret for the given account.
    /// Passing an empty/whitespace string deletes any existing item.
    /// - Returns: `true` on success.
    @discardableResult
    static func set(_ value: String, account: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Always remove any existing item first so we can cleanly insert.
        _ = delete(account: account)

        // Empty value means "clear the key".
        guard !trimmed.isEmpty else { return true }
        guard let data = trimmed.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Retrieve the secret for the given account, or `nil` if not present.
    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
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

    /// Delete the secret for the given account.
    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Whether a non-empty secret exists for the given account.
    static func has(account: String) -> Bool {
        guard let value = get(account: account) else { return false }
        return !value.isEmpty
    }
}
