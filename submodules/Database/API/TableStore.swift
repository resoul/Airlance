import Observers

public protocol SQLReader {
    func fetch(_ sql: String, _ arguments: [SQLValue]) throws -> [SQLRow]
}

public protocol SQLWriter: SQLReader {
    var changes: Int { get }

    func execute(_ sql: String, _ arguments: [SQLValue]) throws
}

extension SQLReader {
    public func fetch(_ sql: String) throws -> [SQLRow] {
        try fetch(sql, [])
    }

    public func fetchOne(_ sql: String, _ arguments: [SQLValue] = []) throws -> SQLRow? {
        try fetch(sql, arguments).first
    }
}

extension SQLWriter {
    public func execute(_ sql: String) throws {
        try execute(sql, [])
    }
}

public struct TableMigration: Sendable {
    public let id: String
    public let apply: @Sendable (any SQLWriter) throws -> Void

    public init(_ id: String, apply: @escaping @Sendable (any SQLWriter) throws -> Void) {
        self.id = id
        self.apply = apply
    }

    public init(_ id: String, sql: String) {
        self.init(id) { db in
            try db.execute(sql)
        }
    }
}

public struct TableSchema: Sendable {
    public let module: String
    public let migrations: [TableMigration]

    public init(module: String, migrations: [TableMigration]) {
        self.module = module
        self.migrations = migrations
    }
}

@MainActor
public protocol TableStore: AnyObject {
    func read<Value: Sendable>(_ body: @escaping @Sendable (any SQLReader) throws -> Value) async throws -> Value

    func write<Value: Sendable>(_ body: @escaping @Sendable (any SQLWriter) throws -> Value) async throws -> Value

    func observe<Value: Sendable & Equatable>(
        _ fetch: @escaping @Sendable (any SQLReader) throws -> Value,
        onError: @escaping @MainActor (StorageError) -> Void,
        onChange: @escaping @MainActor (Value) -> Void
    ) -> ObservationToken
}
