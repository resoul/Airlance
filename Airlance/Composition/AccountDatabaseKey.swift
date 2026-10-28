import Foundation
import Keychain

extension KeychainKey where Value == Data {
    static func accountDatabaseKey(accountID: String) -> KeychainKey<Data> {
        KeychainKey("account.\(accountID).databaseKey")
    }
}

enum AccountDatabaseKey {
    static let byteCount = 32

    static func load(accountID: String, keychain: Keychain) throws -> (data: Data, isNew: Bool) {
        let key = KeychainKey.accountDatabaseKey(accountID: accountID)
        if let existing = try keychain.value(for: key), existing.count == byteCount {
            return (existing, false)
        }

        let created = try Keychain.randomData(count: byteCount)
        try keychain.set(created, for: key)

        return (created, true)
    }

    static func remove(accountID: String, keychain: Keychain) throws {
        try keychain.remove(.accountDatabaseKey(accountID: accountID))
    }
}
