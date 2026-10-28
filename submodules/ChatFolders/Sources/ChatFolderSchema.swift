import DatabaseAPI

public enum ChatFolderSchema {
    public static let schema = TableSchema(
        module: "chatFolders",
        migrations: [
            TableMigration(
                "v1",
                sql: """
                    CREATE TABLE chat_folders (
                        id TEXT PRIMARY KEY NOT NULL,
                        title TEXT NOT NULL CHECK (length(trim(title)) > 0),
                        emoji TEXT,
                        color INTEGER CHECK (color BETWEEN 0 AND 6),
                        position INTEGER NOT NULL,
                        categories INTEGER NOT NULL DEFAULT 0,
                        exclusions INTEGER NOT NULL DEFAULT 0
                    );
                    CREATE INDEX chat_folders_order ON chat_folders(position, id);
                    CREATE TABLE chat_folder_peers (
                        folder_id TEXT NOT NULL REFERENCES chat_folders(id) ON DELETE CASCADE,
                        peer_id TEXT NOT NULL,
                        role TEXT NOT NULL CHECK (role IN ('include', 'exclude')),
                        PRIMARY KEY (folder_id, peer_id)
                    ) WITHOUT ROWID;
                    CREATE INDEX chat_folder_peers_peer ON chat_folder_peers(peer_id);
                    CREATE TABLE chat_folder_settings (
                        key TEXT PRIMARY KEY NOT NULL,
                        value INTEGER NOT NULL
                    );
                    """
            ),
        ]
    )
}
