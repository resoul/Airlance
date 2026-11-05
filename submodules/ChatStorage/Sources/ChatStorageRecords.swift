import DatabaseAPI
import Foundation

enum ChatStorageRecords {
    private static let messageColumns = "chat_id, sender, client_id, message_id, text, sent_at_ms, state, "
        + "author_first_name, author_last_name, author_photo_media_id, author_video_media_id, agent_name, "
        + "attachments, forward_name"
    private static let messagePlaceholders = "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"

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

    static func upsertReceived(
        _ message: StoredMessage,
        countsUnread: Bool,
        isMention: Bool,
        db: any SQLWriter
    ) throws {
        try db.execute("INSERT OR IGNORE INTO server_chats (id) VALUES (?)", [.text(message.chatID)])
        let key: [SQLValue] = [.text(message.chatID), .text(message.sender), .text(message.clientID)]
        let isNew = try db.fetchOne(
            "SELECT 1 AS found FROM server_messages WHERE chat_id = ? AND sender = ? AND client_id = ?",
            key
        ) == nil
        try db.execute(
            "INSERT INTO server_messages (\(messageColumns)) VALUES (\(messagePlaceholders)) "
                + "ON CONFLICT (chat_id, sender, client_id) DO UPDATE SET "
                + "message_id = excluded.message_id, text = excluded.text, "
                + "sent_at_ms = excluded.sent_at_ms, state = excluded.state, "
                + "author_first_name = excluded.author_first_name, author_last_name = excluded.author_last_name, "
                + "author_photo_media_id = excluded.author_photo_media_id, "
                + "author_video_media_id = excluded.author_video_media_id, agent_name = excluded.agent_name, "
                + "attachments = CASE WHEN excluded.attachments = '[]' THEN server_messages.attachments "
                + "ELSE excluded.attachments END, forward_name = excluded.forward_name",
            values(of: message)
        )
        if isNew, countsUnread {
            try db.execute(
                "UPDATE server_chats SET unread = unread + 1, unread_mentions = unread_mentions + ? WHERE id = ?",
                [.integer(isMention ? 1 : 0), .text(message.chatID)]
            )
        }
    }

    static func insertPending(_ message: StoredMessage, db: any SQLWriter) throws {
        try db.execute(
            "INSERT INTO server_messages (\(messageColumns)) VALUES (\(messagePlaceholders)) "
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

    static func saveChat(
        id: String,
        peer: StoredPeer,
        details: StoredChatDetails,
        keepsSettings: Bool,
        db: any SQLWriter
    ) throws {
        try db.execute(
            "INSERT INTO server_chats (id, peer_subject, peer_first_name, peer_last_name, peer_username, "
                + "peer_photo_media_id, peer_video_media_id, kind, title, about, link, invite_token, "
                + "member_count, role, is_pinned, is_muted) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT (id) DO UPDATE SET "
                + (keepsSettings ? "" : "is_pinned = excluded.is_pinned, is_muted = excluded.is_muted, ")
                + "peer_subject = excluded.peer_subject, peer_first_name = excluded.peer_first_name, "
                + "peer_last_name = excluded.peer_last_name, peer_username = excluded.peer_username, "
                + "peer_photo_media_id = excluded.peer_photo_media_id, "
                + "peer_video_media_id = excluded.peer_video_media_id, "
                + "kind = excluded.kind, title = excluded.title, about = excluded.about, link = excluded.link, "
                + "invite_token = excluded.invite_token, member_count = excluded.member_count, role = excluded.role",
            [
                .text(id),
                .text(peer.subject),
                .text(peer.firstName),
                .text(peer.lastName),
                .text(peer.username),
                .text(peer.photoMediaID),
                .text(peer.videoMediaID),
                .integer(Int64(details.kind.rawValue)),
                .text(details.title),
                .text(details.about),
                .text(details.link),
                .text(details.inviteToken),
                .integer(Int64(details.memberCount)),
                .integer(Int64(details.role)),
                .integer(details.isPinned ? 1 : 0),
                .integer(details.isMuted ? 1 : 0),
            ]
        )
    }

    static func isKnown(chatID: String, db: any SQLReader) throws -> Bool {
        let row = try db.fetchOne("SELECT peer_subject, kind FROM server_chats WHERE id = ?", [.text(chatID)])

        return !(row?["peer_subject"].string ?? "").isEmpty || (row?["kind"].int ?? 0) != 0
    }

    static func isHistoryLoaded(chatID: String, db: any SQLReader) throws -> Bool {
        let row = try db.fetchOne("SELECT history_loaded FROM server_chats WHERE id = ?", [.text(chatID)])

        return (row?["history_loaded"].int ?? 0) != 0
    }

    static func removeChat(_ id: String, db: any SQLWriter) throws {
        try db.execute("DELETE FROM server_messages WHERE chat_id = ?", [.text(id)])
        try db.execute("DELETE FROM server_chats WHERE id = ?", [.text(id)])
    }

    static func removeMissing(keeping: Set<String>, before: Int64, db: any SQLWriter) throws {
        let rows = try db.fetch(
            "SELECT c.id AS id, c.kind AS kind, "
                + "(SELECT COUNT(*) FROM server_messages m "
                + "WHERE m.chat_id = c.id AND m.message_id IS NOT NULL) AS sent, "
                + "(SELECT MAX(m.sent_at_ms) FROM server_messages m WHERE m.chat_id = c.id) AS newest "
                + "FROM server_chats c"
        )
        for row in rows {
            let id = row["id"].string ?? ""
            let isGone = (row["kind"].int ?? 0) != 0 || (row["sent"].int ?? 0) > 0
            guard !keeping.contains(id), isGone, Int64(row["newest"].int ?? 0) < before else {
                continue
            }

            try removeChat(id, db: db)
        }
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
                last: last,
                details: details(from: row),
                unreadMentions: row["unread_mentions"].int ?? 0
            )
        }
    }

    static func saveAttachments(of message: StoredMessage, db: any SQLWriter) throws {
        try db.execute(
            "UPDATE server_messages SET attachments = ? WHERE chat_id = ? AND sender = ? AND client_id = ?",
            [.text(encode(message.attachments)), .text(message.chatID), .text(message.sender), .text(message.clientID)]
        )
    }

    private static func encode(_ attachments: [StoredAttachment]) -> String {
        guard let data = try? JSONEncoder().encode(attachments) else {
            return "[]"
        }

        return String(decoding: data, as: UTF8.self)
    }

    private static func decode(_ text: String) -> [StoredAttachment] {
        (try? JSONDecoder().decode([StoredAttachment].self, from: Data(text.utf8))) ?? []
    }

    private static func details(from row: SQLRow) -> StoredChatDetails {
        StoredChatDetails(
            kind: StoredChatKind(rawValue: row["kind"].int ?? 0) ?? .direct,
            title: row["title"].string ?? "",
            about: row["about"].string ?? "",
            link: row["link"].string ?? "",
            inviteToken: row["invite_token"].string ?? "",
            memberCount: row["member_count"].int ?? 0,
            role: row["role"].int ?? 0,
            isPinned: (row["is_pinned"].int ?? 0) != 0,
            isMuted: (row["is_muted"].int ?? 0) != 0
        )
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
            .text(message.author.firstName),
            .text(message.author.lastName),
            .text(message.author.photoMediaID),
            .text(message.author.videoMediaID),
            .text(message.author.agentName),
            .text(encode(message.attachments)),
            .text(message.forwardName),
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
            state: state,
            author: StoredAuthor(
                firstName: row["author_first_name"].string ?? "",
                lastName: row["author_last_name"].string ?? "",
                photoMediaID: row["author_photo_media_id"].string ?? "",
                videoMediaID: row["author_video_media_id"].string ?? "",
                agentName: row["agent_name"].string ?? ""
            ),
            attachments: decode(row["attachments"].string ?? "[]"),
            forwardName: row["forward_name"].string ?? ""
        )
    }
}
