public struct ProtocolEnvelope: Sendable, Equatable {
    public let seq: UInt64
    public let requestID: UInt64
    public let message: ProtocolMessage

    public init(seq: UInt64 = 0, requestID: UInt64 = 0, message: ProtocolMessage) {
        self.seq = seq
        self.requestID = requestID
        self.message = message
    }
}

public enum ProtocolMessage: Sendable, Equatable {
    case ping(id: Int64)
    case pong(id: Int64)
    case error(ServerError)
    case unsupported(kind: UInt16)
}

public struct ServerError: Sendable, Equatable {
    public let code: Int32
    public let message: String

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }
}
