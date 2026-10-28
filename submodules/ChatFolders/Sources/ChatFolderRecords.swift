import DatabaseAPI

enum ChatFolderRecords {
    static func fetch(_ db: any SQLReader) throws -> ChatFolderList {
        var included: [String: Set<String>] = [:]
        var excluded: [String: Set<String>] = [:]
        for row in try db.fetch("SELECT folder_id, peer_id, role FROM chat_folder_peers") {
            let folder = row["folder_id"].string ?? ""
            let peer = row["peer_id"].string ?? ""
            if row["role"].string == "include" {
                included[folder, default: []].insert(peer)
            } else {
                excluded[folder, default: []].insert(peer)
            }
        }

        let folders = try db.fetch("SELECT * FROM chat_folders ORDER BY position, id").compactMap { row in
            folder(from: row, included: included, excluded: excluded)
        }
        let position = try db.fetchOne("SELECT value FROM chat_folder_settings WHERE key = 'allChatsPosition'")

        return ChatFolderList(folders: folders, allChatsPosition: position?["value"].int ?? 0)
    }

    static func insert(_ folder: ChatFolder, db: any SQLWriter) throws {
        let position = try db.fetchOne("SELECT COALESCE(MAX(position), -1) + 1 AS next FROM chat_folders")
        try db.execute(
            """
            INSERT INTO chat_folders (id, title, emoji, color, position, categories, exclusions)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(folder.id),
                .text(folder.name),
                SQLValue(folder.emoji),
                SQLValue(folder.color),
                SQLValue(position?["next"].int ?? 0),
                SQLValue(mask(folder.categories)),
                SQLValue(mask(folder.exclusions)),
            ]
        )
        try replacePeers(of: folder, db: db)
    }

    static func update(_ folder: ChatFolder, db: any SQLWriter) throws {
        try db.execute(
            """
            UPDATE chat_folders SET title = ?, emoji = ?, color = ?, categories = ?, exclusions = ?
            WHERE id = ?
            """,
            [
                .text(folder.name),
                SQLValue(folder.emoji),
                SQLValue(folder.color),
                SQLValue(mask(folder.categories)),
                SQLValue(mask(folder.exclusions)),
                .text(folder.id),
            ]
        )
        guard db.changes == 1 else {
            throw ChatFolderError.unknownFolder
        }

        try replacePeers(of: folder, db: db)
    }

    static func reorder(_ ids: [String], allChatsPosition: Int, db: any SQLWriter) throws {
        let existing = Set(try db.fetch("SELECT id FROM chat_folders").compactMap { row in
            row["id"].string
        })
        guard Set(ids) == existing, ids.count == existing.count, (0...ids.count).contains(allChatsPosition) else {
            throw ChatFolderError.invalidOrder
        }

        for (position, id) in ids.enumerated() {
            try db.execute("UPDATE chat_folders SET position = ? WHERE id = ?", [SQLValue(position), .text(id)])
        }
        try db.execute(
            """
            INSERT INTO chat_folder_settings (key, value) VALUES ('allChatsPosition', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value
            """,
            [SQLValue(allChatsPosition)]
        )
    }

    private static func folder(
        from row: SQLRow,
        included: [String: Set<String>],
        excluded: [String: Set<String>]
    ) -> ChatFolder? {
        guard let id = row["id"].string, let title = row["title"].string else {
            return nil
        }

        var folder = ChatFolder(id: id, name: title)
        folder.emoji = row["emoji"].string
        folder.color = row["color"].int
        folder.categories = set(row["categories"].int ?? 0)
        folder.exclusions = set(row["exclusions"].int ?? 0)
        folder.included = included[id] ?? []
        folder.excluded = excluded[id] ?? []

        return folder
    }

    private static func replacePeers(of folder: ChatFolder, db: any SQLWriter) throws {
        try db.execute("DELETE FROM chat_folder_peers WHERE folder_id = ?", [.text(folder.id)])
        let rows = folder.excluded.map { peer in
            (peer, "exclude")
        } + folder.included.subtracting(folder.excluded).map { peer in
            (peer, "include")
        }
        for (peer, role) in rows {
            try db.execute(
                "INSERT INTO chat_folder_peers (folder_id, peer_id, role) VALUES (?, ?, ?)",
                [.text(folder.id), .text(peer), .text(role)]
            )
        }
    }

    private static func mask<Value: RawRepresentable<Int>>(_ values: Set<Value>) -> Int {
        values.reduce(0) { result, value in
            result | (1 << value.rawValue)
        }
    }

    private static func set<Value: RawRepresentable<Int> & CaseIterable>(_ mask: Int) -> Set<Value> {
        Set(Value.allCases.filter { value in
            mask & (1 << value.rawValue) != 0
        })
    }
}

public enum ChatFolderError: Error {
    case emptyName
    case unknownFolder
    case invalidOrder
}
