import Foundation
import Security

public final class Keychain: Sendable {
    public let service: String
    public let accessGroup: String?
    public let accessibility: KeychainAccessibility

    public init(
        service: String,
        accessGroup: String? = nil,
        accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }

    public func value<Value>(for key: KeychainKey<Value>) throws -> Value? {
        var query = baseQuery(account: key.name)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.decodingFailed
            }

            return try KeychainCoder.decode(Value.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func set<Value>(_ value: Value, for key: KeychainKey<Value>) throws {
        let data = try KeychainCoder.encode(value)
        let query = baseQuery(account: key.name)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.attribute,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let item = query.merging(attributes) { _, new in
                new
            }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func remove<Value>(_ key: KeychainKey<Value>) throws {
        try delete(baseQuery(account: key.name))
    }

    public func removeAll() throws {
        try delete(baseQuery(account: nil))
    }

    public static func randomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw KeychainError.randomFailed(status)
        }

        return Data(bytes)
    }

    private func delete(_ query: [String: Any]) throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}
