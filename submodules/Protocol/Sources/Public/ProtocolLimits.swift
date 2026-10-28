public struct ProtocolLimits: Sendable, Equatable {
    public static let `default` = ProtocolLimits(maxFrameSize: 4 << 20, maxDepth: 32, maxTableCount: 100_000)

    public let maxFrameSize: Int
    public let maxDepth: UInt32
    public let maxTableCount: UInt32

    public init(maxFrameSize: Int, maxDepth: UInt32, maxTableCount: UInt32) {
        self.maxFrameSize = maxFrameSize
        self.maxDepth = maxDepth
        self.maxTableCount = maxTableCount
    }
}
