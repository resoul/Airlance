import Foundation

public struct ProtocolCodec: Sendable {
    private let limits: ProtocolLimits

    public init(limits: ProtocolLimits = .default) {
        self.limits = limits
    }

    public func encode(_ envelope: ProtocolEnvelope) throws(ProtocolError) -> Data {
        try EnvelopeWriter.write(envelope)
    }

    public func decode(_ data: Data) throws(ProtocolError) -> ProtocolEnvelope {
        guard data.count <= limits.maxFrameSize else {
            throw .frameTooLarge(size: data.count, limit: limits.maxFrameSize)
        }

        return try EnvelopeReader(limits: limits).read(data)
    }
}
