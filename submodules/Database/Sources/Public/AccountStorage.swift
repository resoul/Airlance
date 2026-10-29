import DatabaseAPI
import Foundation
import GRDB

@MainActor
public struct AccountDatabase {
    public let keyValue: any KeyValueStore
    public let tables: any TableStore

    let queue: DatabaseQueue

    public func close() async throws {
        let queue = queue
        try await Task.detached {
            try queue.close()
        }.value
    }
}

public enum AccountStorage {
    private static let fileName = "account.sqlite"

    @MainActor
    public static func open(directory: URL, key: Data, schemas: [TableSchema]) throws -> AccountDatabase {
        let file = DatabaseFile(directory: directory, name: fileName, encryption: .key(key), isBackedUp: false)
        let database = try DatabaseConnection.open(file)
        try KeyValueTable.migrate(database)
        try SQLTableStore.migrate(database, schemas: schemas)

        return AccountDatabase(
            keyValue: try SQLKeyValueStore(database: database),
            tables: SQLTableStore(database: database),
            queue: database
        )
    }

    public static func remove(directory: URL) throws {
        let file = DatabaseFile(directory: directory, name: fileName, encryption: .none, isBackedUp: false)
        for path in file.paths where FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }
}
