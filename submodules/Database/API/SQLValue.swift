import Foundation

public enum SQLValue: Sendable, Hashable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    public init(_ value: Int) {
        self = .integer(Int64(value))
    }

    public init(_ value: Bool) {
        self = .integer(value ? 1 : 0)
    }

    public init(_ value: String?) {
        self = value.map(SQLValue.text) ?? .null
    }

    public init(_ value: Int?) {
        self = value.map { value in
            .integer(Int64(value))
        } ?? .null
    }

    public var string: String? {
        switch self {
        case .text(let value):
            value
        case .integer(let value):
            String(value)
        case .real(let value):
            String(value)
        case .null, .blob:
            nil
        }
    }

    public var int: Int? {
        switch self {
        case .integer(let value):
            Int(value)
        case .real(let value):
            Int(value)
        case .text(let value):
            Int(value)
        case .null, .blob:
            nil
        }
    }

    public var bool: Bool {
        (int ?? 0) != 0
    }

    public var data: Data? {
        switch self {
        case .blob(let value):
            value
        case .text(let value):
            Data(value.utf8)
        case .null, .integer, .real:
            nil
        }
    }
}

extension SQLValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByNilLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }

    public init(integerLiteral value: Int) {
        self = .integer(Int64(value))
    }

    public init(nilLiteral: ()) {
        self = .null
    }
}

public struct SQLRow: Sendable, Equatable {
    private let values: [String: SQLValue]

    public init(_ values: [String: SQLValue]) {
        self.values = values
    }

    public subscript(_ column: String) -> SQLValue {
        values[column] ?? .null
    }
}
