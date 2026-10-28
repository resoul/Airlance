import DatabaseAPI
import Foundation
import GRDB

struct SQLContext: SQLWriter {
    let db: Database

    var changes: Int {
        db.changesCount
    }

    func fetch(_ sql: String, _ arguments: [SQLValue]) throws -> [SQLRow] {
        try Row.fetchAll(db, sql: sql, arguments: Self.arguments(arguments)).map(Self.row)
    }

    func execute(_ sql: String, _ arguments: [SQLValue]) throws {
        try db.execute(sql: sql, arguments: Self.arguments(arguments))
    }

    private static func arguments(_ values: [SQLValue]) -> StatementArguments {
        StatementArguments(values.map(databaseValue))
    }

    private static func databaseValue(_ value: SQLValue) -> DatabaseValue {
        switch value {
        case .null:
            .null
        case .integer(let number):
            number.databaseValue
        case .real(let number):
            number.databaseValue
        case .text(let text):
            text.databaseValue
        case .blob(let data):
            data.databaseValue
        }
    }

    private static func row(_ row: Row) -> SQLRow {
        var values: [String: SQLValue] = [:]
        for (column, value) in row {
            values[column] = sqlValue(value)
        }

        return SQLRow(values)
    }

    private static func sqlValue(_ value: DatabaseValue) -> SQLValue {
        switch value.storage {
        case .null:
            .null
        case .int64(let number):
            .integer(number)
        case .double(let number):
            .real(number)
        case .string(let text):
            .text(text)
        case .blob(let data):
            .blob(data)
        }
    }
}
