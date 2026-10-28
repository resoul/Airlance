import ChatFolders
import Database
import DatabaseAPI
import Foundation
import Keychain

@MainActor
final class AccountContext {
    static let schemas = [ChatFolderSchema.schema]

    let accountID: String
    let storage: any KeyValueStore
    let chatFolders: ChatFolderStore
    let chatsStore: ChatsStore
    let callsStore: CallsStore
    let storiesStore: StoriesStore

    init(accountID: String, keychain: Keychain) throws {
        let directory = try Self.directory(accountID: accountID)
        let key = try AccountDatabaseKey.load(accountID: accountID, keychain: keychain)
        if key.isNew {
            try AccountStorage.remove(directory: directory)
        }
        let database = try AccountStorage.open(directory: directory, key: key.data, schemas: Self.schemas)

        self.accountID = accountID
        storage = database.keyValue
        chatFolders = ChatFolderStore(tables: database.tables)
        chatsStore = ChatsStore(chats: ChatFixtures.make(now: Date()))
        callsStore = CallsStore(entries: CallFixtures.make(now: Date()))
        storiesStore = StoriesStore(stories: StoryFixtures.make())
    }

    static func remove(accountID: String, keychain: Keychain) throws {
        try AccountStorage.remove(directory: directory(accountID: accountID))
        try AccountDatabaseKey.remove(accountID: accountID, keychain: keychain)
    }

    private static func directory(accountID: String) throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupport
            .appendingPathComponent("Accounts", isDirectory: true)
            .appendingPathComponent(accountID, isDirectory: true)
    }
}
