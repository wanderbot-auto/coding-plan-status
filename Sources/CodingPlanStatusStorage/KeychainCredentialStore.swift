import Foundation
import Security
import CodingPlanStatusCore

public enum KeychainCredentialStoreError: Error, LocalizedError {
    case osStatus(OSStatus)
    case dataEncoding

    public var errorDescription: String? {
        switch self {
        case .osStatus(let status):
            return "Keychain OSStatus: \(status)"
        case .dataEncoding:
            return "Failed to encode/decode keychain data"
        }
    }
}

public struct KeychainCredentialStore: CredentialStore {
    public init() {}

    public func read(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainCredentialStoreError.osStatus(status)
        }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainCredentialStoreError.dataEncoding
        }
        return string
    }

    public func write(service: String, account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainCredentialStoreError.dataEncoding
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainCredentialStoreError.osStatus(addStatus)
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw KeychainCredentialStoreError.osStatus(updateStatus)
        }
    }

    public func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainCredentialStoreError.osStatus(status)
        }
    }
}
