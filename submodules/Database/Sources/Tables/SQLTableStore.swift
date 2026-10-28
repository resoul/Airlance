import DatabaseAPI
import Foundation
import GRDB
import Observers
import os

@MainActor
final class SQLTableStore: TableStore {
    private static let logger = Logger(subsystem: "Database", category: "Tables")

    private let database: DatabaseQueue

    init(database: DatabaseQueue) {
        self.database = database
    }

    static func migrate(_ database: DatabaseQueue, schemas: [TableSchema]) throws {
        var migrator = DatabaseMigrator()
        for schema in schemas {
            for migration in schema.migrations {
                migrator.registerMigration("\(schema.module).\(migration.id)") { db in
                    try migration.apply(SQLContext(db: db))
                }
            }
        }
        try migrator.migrate(database)
    }

    func read<Value: Sendable>(_ body: @escaping @Sendable (any SQLReader) throws -> Value) async throws -> Value {
        do {
            return try await database.read { db in
                try body(SQLContext(db: db))
            }
        } catch {
            throw StorageError.readFailed(underlying: error)
        }
    }

    func write<Value: Sendable>(_ body: @escaping @Sendable (any SQLWriter) throws -> Value) async throws -> Value {
        do {
            return try await database.write { db in
                try body(SQLContext(db: db))
            }
        } catch {
            throw StorageError.tableWriteFailed(underlying: error)
        }
    }

    func observe<Value: Sendable & Equatable>(
        _ fetch: @escaping @Sendable (any SQLReader) throws -> Value,
        onChange: @escaping @MainActor (Value) -> Void
    ) -> ObservationToken {
        let observation = ValueObservation
            .tracking { db in
                try fetch(SQLContext(db: db))
            }
            .removeDuplicates()
        let cancellable = observation.start(
            in: database,
            scheduling: .immediate,
            onError: { error in
                Self.logger.error("Observation failed: \(String(describing: error), privacy: .public)")
            },
            onChange: onChange
        )
        let box = CancellableBox(cancellable)

        return ObservationToken {
            box.cancel()
        }
    }
}

private final class CancellableBox: @unchecked Sendable {
    private let cancellable: AnyDatabaseCancellable

    init(_ cancellable: AnyDatabaseCancellable) {
        self.cancellable = cancellable
    }

    func cancel() {
        cancellable.cancel()
    }
}
