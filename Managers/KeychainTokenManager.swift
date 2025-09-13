//
//  KeychainTokenManager.swift
//  Lyracalise
//
//  Created by Vishnu Vardhan on 12/9/25.
//

import Foundation
import Security

/// Secure token storage using iOS Keychain - survives app deletion and force-close
class KeychainTokenManager {
    static let shared = KeychainTokenManager()
    
    private let service = "com.vishnu.lyracalise.spotify"
    private let accessTokenKey = "spotify_access_token"
    private let refreshTokenKey = "spotify_refresh_token"
    private let expirationDateKey = "spotify_token_expiration"
    
    private init() {}
    
    // MARK: - Token Storage
    
    func saveTokens(accessToken: String, refreshToken: String?, expirationDate: Date) {
        saveToKeychain(key: accessTokenKey, value: accessToken)
        if let refreshToken = refreshToken {
            saveToKeychain(key: refreshTokenKey, value: refreshToken)
        }
        saveToKeychain(key: expirationDateKey, value: ISO8601DateFormatter().string(from: expirationDate))
    }
    
    func getAccessToken() -> String? {
        return getFromKeychain(key: accessTokenKey)
    }
    
    func getRefreshToken() -> String? {
        return getFromKeychain(key: refreshTokenKey)
    }
    
    func getExpirationDate() -> Date? {
        guard let dateString = getFromKeychain(key: expirationDateKey) else { return nil }
        return ISO8601DateFormatter().date(from: dateString)
    }
    
    func clearAllTokens() {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
        deleteFromKeychain(key: expirationDateKey)
    }
    
    // MARK: - Token Validation
    
    func isTokenValid() -> Bool {
        guard let accessToken = getAccessToken(),
              !accessToken.isEmpty,
              let expirationDate = getExpirationDate() else {
            return false
        }
        
        // Consider token invalid if it expires within 5 minutes
        return Date().addingTimeInterval(300) < expirationDate
    }
    
    func shouldRefreshToken() -> Bool {
        guard let expirationDate = getExpirationDate() else { return false }
        // Refresh if token expires within 5 minutes
        return Date().addingTimeInterval(300) >= expirationDate
    }
    
    // MARK: - Private Keychain Helpers
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save \(key) to Keychain: \(status)")
        }
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}