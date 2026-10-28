import Foundation

public struct MessagePhoto: Sendable, Hashable {
    public let id: String
    public let width: Int
    public let height: Int
    public let source: String

    public init(id: String, width: Int, height: Int, source: String) {
        self.id = id
        self.width = width
        self.height = height
        self.source = source
    }

    public var aspectRatio: Double {
        height > 0 ? Double(width) / Double(height) : 1
    }
}

public enum MessageContent: Sendable, Hashable {
    case text(String)
    case photos([MessagePhoto], caption: String)

    public var text: String {
        switch self {
        case .text(let text):
            text
        case .photos(_, let caption):
            caption
        }
    }
}

public enum DeliveryState: Sendable, Hashable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

public struct HistoryMessage: Identifiable, Sendable, Hashable {
    public let id: String
    public let authorID: String
    public let authorName: String
    public let isOutgoing: Bool
    public let date: Date
    public var content: MessageContent
    public var delivery: DeliveryState

    public init(
        id: String,
        authorID: String,
        authorName: String,
        isOutgoing: Bool,
        date: Date,
        content: MessageContent,
        delivery: DeliveryState = .read
    ) {
        self.id = id
        self.authorID = authorID
        self.authorName = authorName
        self.isOutgoing = isOutgoing
        self.date = date
        self.content = content
        self.delivery = delivery
    }
}
