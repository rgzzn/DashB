//
//  KeychainHelper.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    private init() {}

    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case unexpectedStatus(OSStatus)
    }

    func save(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Query per cancellare l'eventuale item esistente (senza matchare il contenuto, solo account/service)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Elimina elemento esistente se presente
        SecItemDelete(deleteQuery as CFDictionary)

        // Query per aggiungere il nuovo item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Importante: rende il token accessibile dopo il primo sblocco, quindi anche in background dopo un riavvio
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }

        return nil
    }

    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
