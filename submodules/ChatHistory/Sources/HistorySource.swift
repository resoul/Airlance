import Foundation
import Observers

public enum HistoryRequest: Sendable, Hashable {
    case latest(count: Int)
    case around(messageID: String, before: Int, after: Int)
}

public struct HistorySlice: Sendable, Hashable {
    public static let empty = HistorySlice(messages: [], hasOlder: false, hasNewer: false)

    public var messages: [HistoryMessage]
    public var hasOlder: Bool
    public var hasNewer: Bool
    public var unreadFrom: String?
    public var pinned: [HistoryMessage]

    public init(
        messages: [HistoryMessage],
        hasOlder: Bool,
        hasNewer: Bool,
        unreadFrom: String? = nil,
        pinned: [HistoryMessage] = []
    ) {
        self.messages = messages
        self.hasOlder = hasOlder
        self.hasNewer = hasNewer
        self.unreadFrom = unreadFrom
        self.pinned = pinned
    }
}

public struct HistoryEvent: Sendable {
    public let chatID: String
    public let appended: [HistoryMessage]
    public let removed: Set<String>

    public init(chatID: String, appended: [HistoryMessage] = [], removed: Set<String> = []) {
        self.chatID = chatID
        self.appended = appended
        self.removed = removed
    }
}

@MainActor
public protocol HistorySource: AnyObject {
    func slice(_ request: HistoryRequest, in chatID: String) async -> HistorySlice
    func observeHistory(_ onEvent: @escaping @MainActor @Sendable (HistoryEvent) -> Void) -> ObservationToken
}
