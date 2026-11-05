import DatabaseAPI

enum ChatStorageRecords {
    private static let messageColumns = "chat_id, sender, client_id, message_id, text, sent_at_ms, state"

    static func seq(key: String, db: any SQLReader) throws -> UInt64 {
        guard
            let row = try db.fetchOne("SELECT value FROM server_sync WHERE key = ?", [.text(key)]),
            let value = row["value"].int
        else {
            return 0
        }

        return UInt64(max(value, 0))
    }

    static func saveSeq(_ seq: UInt64, key: String, db: any SQLWriter) throws {
        try db.execute(
            "INSERT INTO server_sync (key, value) VALUES (?, ?) "
                + "ON CONFLICT (key) DO UPDATE SET value = excluded.value",
            [.text(key), .integer(Int64(seq))]
        )
    }

    static func upsertReceived(_ message: StoredMessage, countsUnread: Bool, db: any SQLWriter) throws {
        try db.execute("INSERT OR IGNORE INTO server_chats (id) VALUES (?)", [.text(message.chatID)])
        let key: [SQLValue] = [.text(message.chatID), .text(message.sender), .text(message.clientID)]
        let isNew = try db.fetchOne(
            "SELECT 1 AS found FROM server_messages WHERE chat_id = ? AND sender = ? AND client_id = ?",
            key
        ) == nil
        try db.execute(
            "INSERT INTO server_messages (\(messageColumns)) VALUES (?, ?, ?, ?, ?, ?, ?) "
                + "ON CONFLICT (chat_id, sender, client_id) DO UPDATE SET "
                + "message_id = excluded.message_id, text = excluded.text, "
                + "sent_at_ms = excluded.sent_at_ms, state = excluded.state",
            values(of: message)
        )
        if isNew, countsUnread {
            try db.execute("UPDATE server_chats SET unread = unread + 1 WHERE id = ?", [.text(message.chatID)])
        }
    }

    static func insertPending(_ message: StoredMessage, db: any SQLWriter) throws {
        try db.execute(
            "INSERT INTO server_messages (\(messageColumns)) VALUES (?, ?, ?, ?, ?, ?, ?) "
                + "ON CONFLICT (chat_id, sender, client_id) DO UPDATE SET state = excluded.state "
                + "WHERE server_messages.message_id IS NULL",
            values(of: message)
        )
    }

    static func setState(of message: StoredMessage, db: any SQLWriter) throws {
        try db.execute(
            "UPDATE server_messages SET state = ? WHERE chat_id = ? AND sender = ? AND client_id = ? "
                + "AND message_id IS NULL",
            [.text(message.state.rawValue), .text(message.chatID), .text(message.sender), .text(message.clientID)]
        )
    }

    static func saveChat(id: String, peer: StoredPeer, db: any SQLWriter) throws {
        try db.execute(
            "INSERT INTO server_chats (id, peer_subject, peer_first_name, peer_last_name, peer_username, "
                + "peer_photo_media_id, peer_video_media_id) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT (id) DO UPDATE SET "
                + "peer_subject = excluded.peer_subject, peer_first_name = excluded.peer_first_name, "
                + "peer_last_name = excluded.peer_last_name, peer_username = excluded.peer_username, "
                + "peer_photo_media_id = excluded.peer_photo_media_id, "
                + "peer_video_media_id = excluded.peer_video_media_id",
            [
                .text(id),
                .text(peer.subject),
                .text(peer.firstName),
                .text(peer.lastName),
                .text(peer.username),
                .text(peer.photoMediaID),
                .text(peer.videoMediaID),
            ]
        )
    }

    static func hasPeer(chatID: String, db: any SQLReader) throws -> Bool {
        let row = try db.fetchOne("SELECT peer_subject FROM server_chats WHERE id = ?", [.text(chatID)])

        return !(row?["peer_subject"].string ?? "").isEmpty
    }

    static func messages(chatID: String, db: any SQLReader) throws -> [StoredMessage] {
        let rows = try db.fetch(
            "SELECT \(messageColumns) FROM server_messages WHERE chat_id = ? "
                + "ORDER BY message_id IS NULL, message_id, sent_at_ms",
            [.text(chatID)]
        )

        return rows.compactMap(message(from:))
    }

    static func pending(db: any SQLReader) throws -> [StoredMessage] {
        let rows = try db.fetch(
            "SELECT \(messageColumns) FROM server_messages WHERE state = 'sending' ORDER BY sent_at_ms"
        )

        return rows.compactMap(message(from:))
    }

    static func chats(db: any SQLReader) throws -> [StoredChat] {
        try db.fetch("SELECT * FROM server_chats").map { row in
            let id = row["id"].string ?? ""
            let lastRow = try db.fetchOne(
                "SELECT \(messageColumns) FROM server_messages WHERE chat_id = ? "
                    + "ORDER BY message_id IS NULL DESC, message_id DESC, sent_at_ms DESC LIMIT 1",
                [.text(id)]
            )
            let last = lastRow.flatMap(message(from:))

            return StoredChat(
                id: id,
                peer: StoredPeer(
                    subject: row["peer_subject"].string ?? "",
                    firstName: row["peer_first_name"].string ?? "",
                    lastName: row["peer_last_name"].string ?? "",
                    username: row["peer_username"].string ?? "",
                    photoMediaID: row["peer_photo_media_id"].string ?? "",
                    videoMediaID: row["peer_video_media_id"].string ?? ""
                ),
                unread: row["unread"].int ?? 0,
                last: last
            )
        }
    }

    private static func values(of message: StoredMessage) -> [SQLValue] {
        [
            .text(message.chatID),
            .text(message.sender),
            .text(message.clientID),
            message.messageID.map(SQLValue.integer) ?? .null,
            .text(message.text),
            .integer(message.sentAtMs),
            .text(message.state.rawValue),
        ]
    }

    private static func message(from row: SQLRow) -> StoredMessage? {
        guard
            let chatID = row["chat_id"].string,
            let sender = row["sender"].string,
            let clientID = row["client_id"].string,
            let state = row["state"].string.flatMap(StoredMessageState.init(rawValue:))
        else {
            return nil
        }

        return StoredMessage(
            chatID: chatID,
            sender: sender,
            clientID: clientID,
            messageID: row["message_id"].int.map(Int64.init),
            text: row["text"].string ?? "",
            sentAtMs: Int64(row["sent_at_ms"].int ?? 0),
            state: state
        )
    }
}
