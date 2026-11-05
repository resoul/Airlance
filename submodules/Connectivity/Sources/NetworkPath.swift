public struct NetworkPath: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case none
        case wifi
        case cellular
        case wired
        case other
    }

    public let kind: Kind
    public let isExpensive: Bool
    public let isConstrained: Bool

    public var isConnected: Bool {
        kind != .none
    }

    public init(kind: Kind, isExpensive: Bool, isConstrained: Bool) {
        self.kind = kind
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}
