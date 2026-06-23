//
//  KeychainHelper.swift
//  Slate
//

import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    private let service = "com.dayzsolutions.notes.dyz.ollama"
    private let account = "apiKey"
    
    @discardableResult
    func saveApiKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Create new item attributes
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        
        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func readApiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func deleteApiKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
