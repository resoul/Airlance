import DatabaseAPI

public enum ChatStorageSchema {
    public static let schema = TableSchema(
        module: "chatStorage",
        migrations: [
            TableMigration(
                "v1",
                sql: """
                    CREATE TABLE server_chats (
                        id TEXT PRIMARY KEY NOT NULL,
                        peer_subject TEXT NOT NULL DEFAULT '',
                        peer_first_name TEXT NOT NULL DEFAULT '',
                        peer_last_name TEXT NOT NULL DEFAULT '',
                        peer_username TEXT NOT NULL DEFAULT '',
                        unread INTEGER NOT NULL DEFAULT 0
                    );
                    CREATE TABLE server_messages (
                        chat_id TEXT NOT NULL,
                        sender TEXT NOT NULL,
                        client_id TEXT NOT NULL,
                        message_id INTEGER,
                        text TEXT NOT NULL,
                        sent_at_ms INTEGER NOT NULL,
                        state TEXT NOT NULL CHECK (state IN ('sending', 'sent', 'failed')),
                        PRIMARY KEY (chat_id, sender, client_id)
                    ) WITHOUT ROWID;
                    CREATE INDEX server_messages_order ON server_messages(chat_id, message_id);
                    CREATE INDEX server_messages_state ON server_messages(state);
                    CREATE TABLE server_sync (
                        key TEXT PRIMARY KEY NOT NULL,
                        value INTEGER NOT NULL
                    );
                    """
            ),
            TableMigration(
                "v2",
                sql: """
                    ALTER TABLE server_chats ADD COLUMN peer_photo_media_id TEXT NOT NULL DEFAULT '';
                    ALTER TABLE server_chats ADD COLUMN peer_video_media_id TEXT NOT NULL DEFAULT '';
                    """
            ),
        ]
    )
}
