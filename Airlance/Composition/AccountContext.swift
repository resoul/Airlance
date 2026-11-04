import ChatFolders
import Database
import DatabaseAPI
import Foundation
import Keychain
import MediaLoader
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
    let channelSettings: ChannelSettingsStore
    let historyStore: ChatHistoryStore
    let groupMembers = GroupMembersStore()
    let callsStore: CallsStore
    let storiesStore: StoriesStore
    let videoNotes: VideoNoteSettings
    let tabs: TabSettings
    let onAir: OnAirStore
    let media: MediaStore
    let myProfile: MyProfileStore

    private let database: AccountDatabase
    private var isClosed = false

    var accountID: AccountID {
        record.id
    }

    private static func previews(now: Date) -> [ChatSummary] {
        let previews = ChatFixtures.previews(now: now)
        let onAirPreviews = OnAirFixtures.summaries(now: now).filter { summary in
            !previews.contains { preview in
                preview.id == summary.id
            }
        }

        return previews + onAirPreviews
    }

    private static func profileStore(
        storage: any KeyValueStore,
        media: MediaStore,
        channelSettings: ChannelSettingsStore
    ) -> MyProfileStore {
        let store = MyProfileStore(storage: storage, media: media)
        channelSettings.signatureName = {
            store.profile.fullName
        }

        return store
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
        let channelSettings = ChannelSettingsStore(storage: database.keyValue)
        self.channelSettings = channelSettings
        chatsStore = ChatsStore(
            chats: ChatFixtures.make(now: now, variant: record.fixtureVariant),
            previews: Self.previews(now: now),
            channelSettings: channelSettings
        )
        onAir = OnAirStore(
            channels: OnAirFixtures.channels(),
            posts: OnAirFixtures.posts(now: now),
            storage: database.keyValue
        )
        historyStore = ChatHistoryStore(chatsStore: chatsStore, fixtureSalt: record.fixtureVariant)
        callsStore = CallsStore(entries: CallFixtures.make(now: now))
        storiesStore = StoriesStore(stories: StoryFixtures.make())
        videoNotes = VideoNoteSettings(storage: database.keyValue)
        tabs = TabSettings(storage: database.keyValue)
        let media = MediaStore(account: record.id.rawValue)
        self.media = media
        myProfile = Self.profileStore(storage: database.keyValue, media: media, channelSettings: channelSettings)
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
        MediaDiskCache.shared.remove(account: accountID.rawValue)
        try AccountDatabaseKey.remove(accountID: accountID.rawValue, keychain: keychain)
    }

    static func hasData(accountID: AccountID) -> Bool {
        guard let directory = try? directory(accountID: accountID) else {
            return false
        }

        return FileManager.default.fileExists(atPath: directory.path)
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
