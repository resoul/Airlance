import DatabaseAPI
import Foundation
import GRDB
import Observers

@MainActor
final class SQLKeyValueStore: KeyValueStore {
    private let database: DatabaseQueue
    private var observers: [String: ObserverList<Data?>] = [:]
    private var cache: [String: StoredValue]

    init(database: DatabaseQueue) throws {
        self.database = database
        cache = try database.read { db in
            try KeyValueTable.fetchAll(db)
        }
    }

    func value<Value>(for key: StorageKey<Value>) -> Value {
        ValueCoder.decode(cache[key.name]?.data, for: key)
    }

    func observe<Value>(
        _ key: StorageKey<Value>,
        onChange: @escaping @MainActor (Value) -> Void
    ) -> ObservationToken {
        let token = observerList(for: key.name).add { data in
            onChange(ValueCoder.decode(data, for: key))
        }
        onChange(value(for: key))

        return token
    }

    @discardableResult
    func update<Value>(
        _ key: StorageKey<Value>,
        _ transform: @escaping @Sendable (inout Value) -> Void
    ) async throws -> Value {
        let (value, stored) = try await write(key: key.name) { db in
            let current = try KeyValueTable.fetchOne(db, key: key.name)
            var value = ValueCoder.decode(current?.data, for: key)
            transform(&value)
            let data = try ValueCoder.encode(value, for: key)
            let stored = try KeyValueTable.save(db, key: key.name, data: data)

            return (value, stored)
        }

        apply(stored, for: key.name)

        return value
    }

    private func write<Result: Sendable>(
        key: String,
        _ updates: @escaping @Sendable (Database) throws -> Result
    ) async throws -> Result {
        do {
            return try await database.write(updates)
        } catch let error as StorageError {
            throw error
        } catch {
            throw StorageError.writeFailed(key: key, underlying: error)
        }
    }

    private func apply(_ stored: StoredValue, for key: String) {
        if let current = cache[key], current.revision >= stored.revision {
            return
        }

        cache[key] = stored
        observers[key]?.notify(stored.data)
    }

    private func observerList(for key: String) -> ObserverList<Data?> {
        if let list = observers[key] {
            return list
        }

        let list = ObserverList<Data?>()
        observers[key] = list

        return list
    }
}
