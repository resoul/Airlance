public enum ProtocolError: Error, Sendable, Equatable {
    case frameTooLarge(size: Int, limit: Int)
    case invalidEnvelope(reason: String)
    case invalidBody(kind: UInt16, reason: String)
    case unencodable(kind: UInt16)
}
