import Foundation
import Security

struct KeychainService {
    static let shared = KeychainService()

    // Set your shared access group in signing settings to use this.
    // Example: "ABCDE12345.com.example.urlsummary.shared"
    var accessGroup: String? { Bundle.main.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String }

    func set(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let update: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            guard status == errSecSuccess else { throw AppError.llmFailed("Keychain update: \(status)") }
        } else if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess else { throw AppError.llmFailed("Keychain add: \(status)") }
        } else {
            throw AppError.llmFailed("Keychain error: \(status)")
        }
    }

    func get(service: String, account: String) throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            if let data = item as? Data { return String(data: data, encoding: .utf8) }
        } else if status != errSecItemNotFound {
            throw AppError.llmFailed("Keychain read: \(status)")
        }
        return nil
    }
}

