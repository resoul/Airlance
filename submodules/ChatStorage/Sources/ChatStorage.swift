import DatabaseAPI
import Observers

@MainActor
public final class ChatStorage {
    nonisolated private static let seqKey = "updatesSeq"

    private let tables: any TableStore
    private let messageObservers = ObserverList<StoredMessagesEvent>()

    public init(tables: any TableStore) {
        self.tables = tables
    }

    public func observeChats(
        onError: @escaping @MainActor (StorageError) -> Void,
        onChange: @escaping @MainActor ([StoredChat]) -> Void
    ) -> ObservationToken {
        let fetch: @Sendable (any SQLReader) throws -> [StoredChat] = { db in
            try ChatStorageRecords.chats(db: db)
        }

        return tables.observe(fetch, onError: onError, onChange: onChange)
    }

    public func observeMessages(
        _ onEvent: @escaping @MainActor @Sendable (StoredMessagesEvent) -> Void
    ) -> ObservationToken {
        messageObservers.add(onEvent)
    }

    public func seq() async throws -> UInt64 {
        try await tables.read { db in
            try ChatStorageRecords.seq(key: Self.seqKey, db: db)
        }
    }

    public func saveSeq(_ seq: UInt64) async throws {
        try await tables.write { db in
            try ChatStorageRecords.saveSeq(seq, key: Self.seqKey, db: db)
        }
    }

    public func messages(in chatID: String) async throws -> [StoredMessage] {
        try await tables.read { db in
            try ChatStorageRecords.messages(chatID: chatID, db: db)
        }
    }

    public func pending() async throws -> [StoredMessage] {
        try await tables.read { db in
            try ChatStorageRecords.pending(db: db)
        }
    }

    public func applyReceived(
        _ message: StoredMessage,
        seq: UInt64?,
        countsUnread: Bool,
        isMention: Bool = false
    ) async throws -> Bool {
        let isKnown = try await tables.write { db in
            try ChatStorageRecords.upsertReceived(message, countsUnread: countsUnread, isMention: isMention, db: db)
            if let seq {
                try ChatStorageRecords.saveSeq(seq, key: Self.seqKey, db: db)
            }

            return try ChatStorageRecords.isKnown(chatID: message.chatID, db: db)
        }
        publish(message)

        return isKnown
    }

    public func addPending(_ message: StoredMessage) async throws {
        try await tables.write { db in
            try ChatStorageRecords.insertPending(message, db: db)
        }
        publish(message)
    }

    public func setFailed(_ message: StoredMessage) async throws {
        var failed = message
        failed.state = .failed
        try await tables.write { [failed] db in
            try ChatStorageRecords.setState(of: failed, db: db)
        }
        publish(failed)
    }

    public func saveChat(
        id: String,
        peer: StoredPeer,
        details: StoredChatDetails = StoredChatDetails(),
        keepsSettings: Bool = false
    ) async throws {
        try await tables.write { db in
            try ChatStorageRecords.saveChat(id: id, peer: peer, details: details, keepsSettings: keepsSettings, db: db)
        }
    }

    public func setMuted(_ isMuted: Bool, chatID: String) async throws {
        try await tables.write { db in
            try db.execute(
                "UPDATE server_chats SET is_muted = ? WHERE id = ?",
                [.integer(isMuted ? 1 : 0), .text(chatID)]
            )
        }
    }

    public func setPinned(_ isPinned: Bool, chatID: String) async throws {
        try await tables.write { db in
            try db.execute(
                "UPDATE server_chats SET is_pinned = ? WHERE id = ?",
                [.integer(isPinned ? 1 : 0), .text(chatID)]
            )
        }
    }

    public func saveAttachments(of message: StoredMessage) async throws {
        try await tables.write { db in
            try ChatStorageRecords.saveAttachments(of: message, db: db)
        }
    }

    public func isHistoryLoaded(_ chatID: String) async throws -> Bool {
        try await tables.read { db in
            try ChatStorageRecords.isHistoryLoaded(chatID: chatID, db: db)
        }
    }

    public func markHistoryLoaded(_ chatID: String) async throws {
        try await tables.write { db in
            try db.execute("UPDATE server_chats SET history_loaded = 1 WHERE id = ?", [.text(chatID)])
        }
    }

    public func removeChat(_ id: String) async throws {
        try await tables.write { db in
            try ChatStorageRecords.removeChat(id, db: db)
        }
    }

    public func removeChats(missingFrom keeping: Set<String>, before: Int64) async throws {
        try await tables.write { db in
            try ChatStorageRecords.removeMissing(keeping: keeping, before: before, db: db)
        }
    }

    public func markRead(_ chatID: String) async throws {
        try await tables.write { db in
            try db.execute(
                "UPDATE server_chats SET unread = 0, unread_mentions = 0 WHERE id = ? AND unread <> 0",
                [.text(chatID)]
            )
        }
    }

    private func publish(_ message: StoredMessage) {
        messageObservers.notify(StoredMessagesEvent(chatID: message.chatID, messages: [message]))
    }
}
