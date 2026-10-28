import DatabaseAPI
import Observers

@MainActor
public final class ChatFolderStore {
    public private(set) var list = ChatFolderList.empty

    private let tables: any TableStore
    private let observers = ObserverList<ChatFolderList>()
    private var observation: ObservationToken?

    public init(tables: any TableStore) {
        self.tables = tables
        observation = tables.observe(ChatFolderRecords.fetch) { [weak self] list in
            self?.publish(list)
        }
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (ChatFolderList) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(list)

        return token
    }

    public func folder(id: String) -> ChatFolder? {
        list.folders.first { folder in
            folder.id == id
        }
    }

    public func save(_ folder: ChatFolder) async throws {
        guard let folder = folder.normalized() else {
            throw ChatFolderError.emptyName
        }

        let isNew = self.folder(id: folder.id) == nil
        try await tables.write { db in
            if isNew {
                try ChatFolderRecords.insert(folder, db: db)
            } else {
                try ChatFolderRecords.update(folder, db: db)
            }
        }
    }

    public func delete(id: String) async throws {
        try await tables.write { db in
            try db.execute("DELETE FROM chat_folders WHERE id = ?", [.text(id)])
            let count = try db.fetchOne("SELECT COUNT(*) AS count FROM chat_folders")?["count"].int ?? 0
            try db.execute(
                "UPDATE chat_folder_settings SET value = MIN(value, ?) WHERE key = 'allChatsPosition'",
                [SQLValue(count)]
            )
        }
    }

    public func reorder(_ ids: [String], allChatsPosition: Int) async throws {
        try await tables.write { db in
            try ChatFolderRecords.reorder(ids, allChatsPosition: allChatsPosition, db: db)
        }
    }

    private func publish(_ list: ChatFolderList) {
        guard list != self.list else {
            return
        }

        self.list = list
        observers.notify(list)
    }
}
