import Foundation

public struct HistoryBuilder: Sendable {
    public var calendar: Calendar
    public var joinInterval: TimeInterval

    public init(calendar: Calendar = .current, joinInterval: TimeInterval = 5 * 60) {
        self.calendar = calendar
        self.joinInterval = joinInterval
    }

    public func entries(for messages: [HistoryMessage], unreadFrom: String? = nil) -> [HistoryEntry] {
        var entries: [HistoryEntry] = []
        entries.reserveCapacity(messages.count + 8)
        for (index, message) in messages.enumerated() {
            let previous = index > 0 ? messages[index - 1] : nil
            let next = index + 1 < messages.count ? messages[index + 1] : nil
            if previous.map({ previous in
                !calendar.isDate(previous.date, inSameDayAs: message.date)
            }) ?? true {
                entries.append(.date(calendar.startOfDay(for: message.date)))
            }
            if message.id == unreadFrom {
                entries.append(.unread)
            }

            let grouping = HistoryGrouping(
                joinedTop: previous.map { previous in
                    message.id != unreadFrom && joins(previous, message)
                } ?? false,
                joinedBottom: next.map { next in
                    next.id != unreadFrom && joins(message, next)
                } ?? false
            )
            entries.append(.message(message, grouping))
        }

        return entries
    }

    private func joins(_ first: HistoryMessage, _ second: HistoryMessage) -> Bool {
        first.authorID == second.authorID
            && first.isOutgoing == second.isOutgoing
            && calendar.isDate(first.date, inSameDayAs: second.date)
            && second.date.timeIntervalSince(first.date) < joinInterval
    }
}
