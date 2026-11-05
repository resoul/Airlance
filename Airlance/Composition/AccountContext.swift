import ChatFolders
import ChatStorage
import Connectivity
import Database
import DatabaseAPI
import Foundation
import Keychain
import MediaLoader
import MediaStore
import Observers
import os

@MainActor
final class AccountContext {
    nonisolated static let mediaLimit: Int64 = 2 * 1024 * 1024 * 1024
    static let schemas = [ChatFolderSchema.schema, ChatStorageSchema.schema]
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
    let connectionStatus: ConnectionStatusStore
    let chatStorage: ChatStorage
    let profileFiles = ProfileMediaFiles()
    let privacy = PrivacyStore()
    let agents = AgentsStore()
    private(set) lazy var serverContacts = ServerContactsStore(
        isServerBacked: record.subject != nil,
        files: profileFiles
    )

    private var serverChats: ObservationToken?
    var ownProfileObservation: ObservationToken?
    private let database: AccountDatabase
    private var isClosed = false

    var accountID: AccountID {
        record.id
    }

    private static func profileStore(
        record: AccountRecord,
        storage: any KeyValueStore,
        media: MediaStore,
        channelSettings: ChannelSettingsStore
    ) -> MyProfileStore {
        let store = MyProfileStore(storage: storage, media: media, usesDemoProfile: record.isDemo)
        channelSettings.signatureName = {
            store.profile.fullName
        }

        return store
    }

    init(record: AccountRecord, keychain: Keychain, network: NetworkMonitor) throws {
        let directory = try Self.directory(accountID: record.id)
        let key = try AccountDatabaseKey.load(accountID: record.id.rawValue, keychain: keychain)
        if key.isNew {
            try AccountStorage.remove(directory: directory)
        }
        let database = try AccountStorage.open(directory: directory, key: key.data, schemas: Self.schemas)
        let content = AccountContent.forAccount(record, now: Date())

        self.record = record
        self.database = database
        connectionStatus = ConnectionStatusStore(network: network)
        storage = database.keyValue
        chatFolders = ChatFolderStore(tables: database.tables)
        let channelSettings = ChannelSettingsStore(storage: database.keyValue)
        self.channelSettings = channelSettings
        chatsStore = ChatsStore(chats: content.chats, previews: content.previews, channelSettings: channelSettings)
        onAir = OnAirStore(channels: content.onAirChannels, posts: content.onAirPosts, storage: database.keyValue)
        let chatStorage = ChatStorage(tables: database.tables)
        self.chatStorage = chatStorage
        let server = Self.serverHistory(record, storage: chatStorage)
        let salt = record.isDemo ? record.fixtureVariant : nil
        historyStore = ChatHistoryStore(chatsStore: chatsStore, fixtureSalt: salt, server: server)
        callsStore = CallsStore(entries: content.calls)
        storiesStore = StoriesStore(stories: content.stories)
        videoNotes = VideoNoteSettings(storage: database.keyValue)
        tabs = TabSettings(storage: database.keyValue)
        let media = MediaStore(account: record.id.rawValue)
        self.media = media
        let keyValue = database.keyValue
        myProfile = Self.profileStore(record: record, storage: keyValue, media: media, channelSettings: channelSettings)
        Task.detached(priority: .background) {
            media.trim(to: Self.mediaLimit)
        }
        historyStore.startFeed()
        observeServerChats()
    }

    private func observeServerChats() {
        myProfile.files = profileFiles
        registerOwnStories()
        guard let me = record.subject else {
            return
        }

        serverChats = chatStorage.observeChats { error in
            Self.logger.error("Can't read the chats: \(String(describing: error))")
        } onChange: { [weak self] stored in
            let chats = stored.map { chat in
                ChatSummary.server(chat, me: me, contacts: self?.serverContacts) { item in
                    self?.rowThumbnail(item)
                }
            }
            self?.registerPeerAvatars(stored)
            let empty = chats.filter { chat in
                chat.kind == .person && chat.preview == nil && chat.message.isEmpty
            }
            self?.chatsStore.setServerChats(chats.filter { chat in
                chat.kind != .person || chat.preview != nil || !chat.message.isEmpty
            }, empty: empty)
        }
        historyStore.onServerAuthor = { [weak self] message in
            self?.registerAuthor(message)
        }
    }

    private static func serverHistory(_ record: AccountRecord, storage: ChatStorage) -> ServerHistory? {
        record.subject.map { subject in
            ServerHistory(storage: storage, me: subject, account: record.id.rawValue)
        }
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
