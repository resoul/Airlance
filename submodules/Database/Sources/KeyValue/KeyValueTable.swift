import Foundation
import GRDB

struct StoredValue: Sendable {
    let data: Data
    let revision: Int64
}

enum KeyValueTable {
    static func migrate(_ database: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("keyValue.v1") { db in
            try db.create(table: "key_value") { table in
                table.primaryKey("key", .text)
                table.column("value", .blob).notNull()
                table.column("revision", .integer).notNull()
            }
        }
        try migrator.migrate(database)
    }

    static func fetchAll(_ db: Database) throws -> [String: StoredValue] {
        let rows = try Row.fetchAll(db, sql: "SELECT key, value, revision FROM key_value")
        var values: [String: StoredValue] = [:]
        for row in rows {
            values[row["key"]] = storedValue(from: row)
        }

        return values
    }

    static func fetchOne(_ db: Database, key: String) throws -> StoredValue? {
        let row = try Row.fetchOne(
            db,
            sql: "SELECT value, revision FROM key_value WHERE key = ?",
            arguments: [key]
        )

        return row.map(storedValue(from:))
    }

    static func save(_ db: Database, key: String, data: Data) throws -> StoredValue {
        let revision = try Int64.fetchOne(
            db,
            sql: """
                INSERT INTO key_value (key, value, revision) VALUES (?, ?, 1)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value, revision = revision + 1
                RETURNING revision
                """,
            arguments: [key, data]
        )
        guard let revision else {
            throw KeyValueTableError.missingRevision
        }

        return StoredValue(data: data, revision: revision)
    }

    private static func storedValue(from row: Row) -> StoredValue {
        StoredValue(data: row["value"], revision: row["revision"])
    }
}

enum KeyValueTableError: Error {
    case missingRevision
}
