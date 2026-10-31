import ChatFolders
import Database
import DatabaseAPI
import Foundation
import Keychain
import MediaStore
import os

@MainActor
final class AccountContext {
    nonisolated static let mediaLimit: Int64 = 2 * 1024 * 1024 * 1024
    static let schemas = [ChatFolderSchema.schema]
    private static let logger = Logger(subsystem: "Airlance", category: "Accounts")

    let record: AccountRecord
    let storage: any KeyValueStore
    let chatFolders: ChatFolderStore
    let chatsStore: ChatsStore
    let historyStore: ChatHistoryStore
    let callsStore: CallsStore
    let storiesStore: StoriesStore
    let videoNotes: VideoNoteSettings
    let media: MediaStore

    private let database: AccountDatabase
    private var isClosed = false

    var accountID: AccountID {
        record.id
    }

    init(record: AccountRecord, keychain: Keychain) throws {
        let directory = try Self.directory(accountID: record.id)
        let key = try AccountDatabaseKey.load(accountID: record.id.rawValue, keychain: keychain)
        if key.isNew {
            try AccountStorage.remove(directory: directory)
        }
        let database = try AccountStorage.open(directory: directory, key: key.data, schemas: Self.schemas)
        let now = Date()

        self.record = record
        self.database = database
        storage = database.keyValue
        chatFolders = ChatFolderStore(tables: database.tables)
        chatsStore = ChatsStore(chats: ChatFixtures.make(now: now, variant: record.fixtureVariant))
        historyStore = ChatHistoryStore(chatsStore: chatsStore, fixtureSalt: record.fixtureVariant)
        callsStore = CallsStore(entries: CallFixtures.make(now: now))
        storiesStore = StoriesStore(stories: StoryFixtures.make())
        videoNotes = VideoNoteSettings(storage: database.keyValue)
        let media = MediaStore(account: record.id.rawValue)
        self.media = media
        Task.detached(priority: .background) {
            media.trim(to: Self.mediaLimit)
        }
        historyStore.startFeed()
    }

    func close() async {
        guard !isClosed else {
            return
        }

        isClosed = true
        await historyStore.shutdown()
        do {
            try await database.close()
        } catch {
            Self.logger.error("Can't close the database of account \(self.record.id.rawValue): \(error)")
        }
    }

    static func remove(accountID: AccountID, keychain: Keychain) throws {
        try AccountStorage.remove(directory: directory(accountID: accountID))
        try? FileManager.default.removeItem(at: directory(accountID: accountID))
        MediaStore(account: accountID.rawValue).removeAll()
        try AccountDatabaseKey.remove(accountID: accountID.rawValue, keychain: keychain)
    }

    private static func directory(accountID: AccountID) throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupport
            .appendingPathComponent("Accounts", isDirectory: true)
            .appendingPathComponent(accountID.rawValue, isDirectory: true)
    }
}
