import Foundation
import MediaStore

public struct MessageVideoNote: Sendable, Hashable {
    public enum Style: String, Sendable, Hashable {
        case blob
        case dualCamera
        case anonymous
        case moment
        case reaction
    }

    public let source: MediaSource
    public let frontSource: MediaSource?
    public let duration: TimeInterval
    public let style: Style
    public let levels: [UInt8]

    public init(
        source: MediaSource,
        frontSource: MediaSource? = nil,
        duration: TimeInterval,
        style: Style,
        levels: [UInt8] = []
    ) {
        self.source = source
        self.frontSource = frontSource
        self.duration = duration
        self.style = style
        self.levels = levels
    }
}

public struct MessageVideoReaction: Sendable, Hashable, Identifiable {
    public let id: String
    public let author: MessageCommenter
    public let note: MessageVideoNote

    public init(id: String, author: MessageCommenter, note: MessageVideoNote) {
        self.id = id
        self.author = author
        self.note = note
    }
}
