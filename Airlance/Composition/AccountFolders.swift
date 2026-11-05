import ChatFolders
import Foundation
import os
import Protocol
import ServerConnection

@MainActor
final class AccountFolders {
    private static let logger = Logger(subsystem: "Airlance", category: "Folders")

    private let connection: ServerConnection
    private let store: ChatFolderStore
    private var isSyncing = false
    private var syncsAgain = false

    init(connection: ServerConnection, store: ChatFolderStore) {
        self.connection = connection
        self.store = store
        store.onLocalChange = { [weak self] in
            self?.sync()
        }
    }

    func sync() {
        guard !isSyncing else {
            syncsAgain = true

            return
        }

        isSyncing = true
        Task {
            await run()
            isSyncing = false
            if syncsAgain {
                syncsAgain = false
                sync()
            }
        }
    }

    private func run() async {
        do {
            let isDirty = try await store.isDirty()
            let remote = try await request(.foldersGet)
            let local = store.list
            let isFirst = remote.revision == 0 && !local.folders.isEmpty
            if isDirty || isFirst {
                try await store.clearDirty()
                _ = try await request(.foldersPut(Self.server(local)))
            } else {
                try await store.replaceAll(Self.local(remote))
            }
        } catch {
            Self.logger.debug("Folders wait for the connection: \(String(describing: error))")
            try? await store.markDirtyIfNeeded()
        }
    }

    private func request(_ message: AutomationWireMessage) async throws -> ServerFolderList {
        guard case .automation(.folders(let list)) = try await connection.request(.automation(message)) else {
            throw AutomationError.refused
        }

        return list
    }

    private static func server(_ list: ChatFolderList) -> ServerFolderList {
        ServerFolderList(
            folders: list.folders.map { folder in
                ServerFolder(
                    id: folder.id,
                    name: folder.name,
                    emoji: folder.emoji ?? "",
                    color: Int32(folder.color ?? -1),
                    categories: Int32(mask(folder.categories)),
                    exclusions: Int32(mask(folder.exclusions)),
                    included: folder.included.sorted(),
                    excluded: folder.excluded.sorted()
                )
            },
            allChatsPosition: Int32(list.allChatsPosition),
            showsTags: list.showsTags,
            revision: 0
        )
    }

    private static func local(_ list: ServerFolderList) -> ChatFolderList {
        let folders = list.folders.map { item in
            var folder = ChatFolder(id: item.id, name: item.name)
            folder.emoji = item.emoji.isEmpty ? nil : item.emoji
            folder.color = item.color < 0 ? nil : Int(item.color)
            folder.categories = set(Int(item.categories))
            folder.exclusions = set(Int(item.exclusions))
            folder.included = Set(item.included)
            folder.excluded = Set(item.excluded)

            return folder
        }

        return ChatFolderList(
            folders: folders,
            allChatsPosition: Int(list.allChatsPosition),
            showsTags: list.showsTags
        )
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
