import DatabaseAPI
import Foundation

struct AccountID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    static let legacyLocal = AccountID(rawValue: "local")

    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String {
        rawValue
    }

    static func make() -> AccountID {
        AccountID(rawValue: "demo-" + UUID().uuidString.prefix(8).lowercased())
    }
}

struct AccountRecord: Codable, Sendable, Hashable, Identifiable {
    let id: AccountID
    let name: String
    let isDemo: Bool
    let fixtureVariant: Int
    let createdAt: Date
}

extension StorageKey where Value == [AccountRecord] {
    static let accounts = StorageKey("accounts.list", default: [])
}

extension StorageKey where Value == String? {
    static let selectedAccount = StorageKey("accounts.selected", default: nil)
}

extension StorageKey where Value == Bool {
    static let accountsMigrated = StorageKey("accounts.migrated", default: false)
}
