import Foundation

public struct HistoryGrouping: Sendable, Hashable {
    public var joinedTop: Bool
    public var joinedBottom: Bool

    public init(joinedTop: Bool = false, joinedBottom: Bool = false) {
        self.joinedTop = joinedTop
        self.joinedBottom = joinedBottom
    }
}

public enum HistoryEntry: Identifiable, Sendable, Hashable {
    case date(Date)
    case unread
    case message(HistoryMessage, HistoryGrouping)

    public var id: String {
        switch self {
        case .date(let day):
            "date-\(Int(day.timeIntervalSince1970))"
        case .unread:
            "unread"
        case .message(let message, _):
            message.id
        }
    }
}
