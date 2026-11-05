import DatabaseAPI
import Observers

public enum ChatFolderStatus: Sendable, Equatable {
    case loading
    case ready
    case failed
}

@MainActor
public final class ChatFolderStore {
    public private(set) var list = ChatFolderList.empty
    public private(set) var status = ChatFolderStatus.loading
    public var onLocalChange: (@MainActor () -> Void)?

    private let tables: any TableStore
    private let observers = ObserverList<ChatFolderList>()
    private var observation: ObservationToken?

    public init(tables: any TableStore) {
        self.tables = tables
        startObserving()
    }

    public func retry() {
        guard status == .failed else {
            return
        }

        publish(list, status: .loading)
        startObserving()
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

        try await tables.write { db in
            try ChatFolderRecords.save(folder, db: db)
            try ChatFolderRecords.setDirty(true, db: db)
        }
        onLocalChange?()
    }

    public func isDirty() async throws -> Bool {
        try await tables.read { db in
            try ChatFolderRecords.isDirty(db)
        }
    }

    public func clearDirty() async throws {
        try await tables.write { db in
            try ChatFolderRecords.setDirty(false, db: db)
        }
    }

    public func markDirtyIfNeeded() async throws {
        guard !list.folders.isEmpty else {
            return
        }

        try await tables.write { db in
            try ChatFolderRecords.setDirtyIfMissing(db: db)
        }
    }

    public func replaceAll(_ next: ChatFolderList) async throws {
        guard next != list else {
            return
        }

        try await tables.write { db in
            guard try !ChatFolderRecords.isDirty(db) else {
                return
            }

            try ChatFolderRecords.replaceAll(next, db: db)
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
            try ChatFolderRecords.setDirty(true, db: db)
        }
        onLocalChange?()
    }

    public func setShowsTags(_ showsTags: Bool) async throws {
        try await tables.write { db in
            try db.execute(
                """
                INSERT INTO chat_folder_settings (key, value) VALUES ('showsTags', ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                [SQLValue(showsTags ? 1 : 0)]
            )
            try ChatFolderRecords.setDirty(true, db: db)
        }
        onLocalChange?()
    }

    public func reorder(_ ids: [String], allChatsPosition: Int) async throws {
        try await tables.write { db in
            try ChatFolderRecords.reorder(ids, allChatsPosition: allChatsPosition, db: db)
            try ChatFolderRecords.setDirty(true, db: db)
        }
        onLocalChange?()
    }

    private func startObserving() {
        observation = nil
        observation = tables.observe(
            ChatFolderRecords.fetch,
            onError: { [weak self] _ in
                guard let self else {
                    return
                }

                self.observation = nil
                self.publish(self.list, status: .failed)
            },
            onChange: { [weak self] list in
                self?.publish(list, status: .ready)
            }
        )
    }

    private func publish(_ list: ChatFolderList, status: ChatFolderStatus) {
        guard list != self.list || status != self.status else {
            return
        }

        self.list = list
        self.status = status
        observers.notify(list)
    }
}
