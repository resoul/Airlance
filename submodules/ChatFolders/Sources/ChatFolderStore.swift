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
