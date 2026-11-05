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

    public func applyReceived(_ message: StoredMessage, seq: UInt64?, countsUnread: Bool) async throws -> Bool {
        let hasPeer = try await tables.write { db in
            try ChatStorageRecords.upsertReceived(message, countsUnread: countsUnread, db: db)
            if let seq {
                try ChatStorageRecords.saveSeq(seq, key: Self.seqKey, db: db)
            }

            return try ChatStorageRecords.hasPeer(chatID: message.chatID, db: db)
        }
        publish(message)

        return hasPeer
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

    public func saveChat(id: String, peer: StoredPeer) async throws {
        try await tables.write { db in
            try ChatStorageRecords.saveChat(id: id, peer: peer, db: db)
        }
    }

    public func markRead(_ chatID: String) async throws {
        try await tables.write { db in
            try db.execute("UPDATE server_chats SET unread = 0 WHERE id = ? AND unread <> 0", [.text(chatID)])
        }
    }

    private func publish(_ message: StoredMessage) {
        messageObservers.notify(StoredMessagesEvent(chatID: message.chatID, messages: [message]))
    }
}
