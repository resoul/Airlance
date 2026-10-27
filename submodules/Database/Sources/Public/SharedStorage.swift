import DatabaseAPI
import Foundation

public enum SharedStorage {
    private static let fileName = "shared.sqlite"

    @MainActor
    public static func open(directory: URL) throws -> any KeyValueStore {
        let file = DatabaseFile(directory: directory, name: fileName, encryption: .none, isBackedUp: true)
        let database = try DatabaseConnection.open(file)
        try KeyValueTable.migrate(database)

        return try SQLKeyValueStore(database: database)
    }
}
