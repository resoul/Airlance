import Foundation

public struct HistoryWindowLimits: Sendable, Hashable {
    public var dataSize: Int
    public var dataThreshold: Int
    public var itemSize: Int
    public var itemMargin: Int
    public var itemThreshold: Int

    public init(
        dataSize: Int = 300,
        dataThreshold: Int = 50,
        itemSize: Int = 150,
        itemMargin: Int = 40,
        itemThreshold: Int = 20
    ) {
        self.dataSize = dataSize
        self.dataThreshold = dataThreshold
        self.itemSize = itemSize
        self.itemMargin = itemMargin
        self.itemThreshold = itemThreshold
    }
}

public struct HistoryWindow: Sendable {
    public let limits: HistoryWindowLimits
    public private(set) var data = HistorySlice.empty
    public private(set) var items: Range<Int> = 0..<0

    private var indices: [String: Int] = [:]

    public init(limits: HistoryWindowLimits = HistoryWindowLimits()) {
        self.limits = limits
    }

    public var isAtEnd: Bool {
        !data.hasNewer && items.upperBound == data.messages.count
    }

    public var itemMessages: ArraySlice<HistoryMessage> {
        data.messages[items]
    }

    public var contextBefore: HistoryMessage? {
        items.lowerBound > 0 ? data.messages[items.lowerBound - 1] : nil
    }

    public var contextAfter: HistoryMessage? {
        items.upperBound < data.messages.count ? data.messages[items.upperBound] : nil
    }

    public func index(of id: String) -> Int? {
        indices[id]
    }

    public func message(_ id: String) -> HistoryMessage? {
        indices[id].map { index in
            data.messages[index]
        } ?? data.pinned.first { message in
            message.id == id
        }
    }

    public var latestRequest: HistoryRequest {
        .latest(count: limits.dataSize)
    }

    public func request(around id: String) -> HistoryRequest {
        .around(messageID: id, before: limits.dataSize / 2, after: limits.dataSize / 2)
    }

    public func refreshRequest(removing removed: Set<String>) -> HistoryRequest {
        let kept = data.messages.filter { message in
            !removed.contains(message.id)
        }
        guard data.hasNewer, let first = kept.first else {
            return .latest(count: max(limits.dataSize, kept.count))
        }

        return .around(messageID: first.id, before: 0, after: kept.count - 1)
    }

    public mutating func setData(_ slice: HistorySlice, focus: String?, keepsEnd: Bool) {
        let previous = data.messages
        data = slice
        indices = Dictionary(uniqueKeysWithValues: slice.messages.enumerated().map { index, message in
            (message.id, index)
        })
        let count = slice.messages.count
        let anchor = focus.flatMap { focus in
            indices[focus] ?? fallback(for: focus, in: previous).flatMap { id in
                indices[id]
            }
        }
        switch (anchor, keepsEnd) {
        case (let anchor?, true):
            items = range(covering: anchor..<count)
        case (let anchor?, false):
            items = range(covering: anchor..<(anchor + 1))
        case (nil, _):
            items = range(covering: max(0, count - 1)..<count)
        }
    }

    public mutating func focus(_ id: String) -> Bool {
        guard let index = indices[id] else {
            return false
        }

        items = range(covering: index..<(index + 1))

        return true
    }

    public mutating func visibleChanged(_ visible: Range<Int>) -> Bool {
        let count = data.messages.count
        let nearTop = items.lowerBound > 0 && visible.lowerBound - items.lowerBound < limits.itemThreshold
        let nearBottom = items.upperBound < count && items.upperBound - visible.upperBound < limits.itemThreshold
        guard nearTop || nearBottom else {
            return false
        }

        let next = range(covering: visible)
        guard next != items else {
            return false
        }

        items = next

        return true
    }

    public func dataRequest(visible: Range<Int>) -> HistoryRequest? {
        let messages = data.messages
        if data.hasOlder, visible.lowerBound < limits.dataThreshold, messages.indices.contains(visible.lowerBound) {
            return request(around: messages[visible.lowerBound].id)
        }

        let last = visible.upperBound - 1
        if data.hasNewer, messages.count - visible.upperBound < limits.dataThreshold, messages.indices.contains(last) {
            return request(around: messages[last].id)
        }

        return nil
    }

    public func fallback(for id: String, in order: [HistoryMessage]) -> String? {
        guard let index = order.firstIndex(where: { message in
            message.id == id
        }) else {
            return nil
        }

        let below = order[(index + 1)...].first { message in
            indices[message.id] != nil
        }
        let above = order[..<index].last { message in
            indices[message.id] != nil
        }

        return (below ?? above)?.id
    }

    private func range(covering visible: Range<Int>) -> Range<Int> {
        let count = data.messages.count
        var lower = max(0, visible.lowerBound - limits.itemMargin)
        var upper = min(count, visible.upperBound + limits.itemMargin)
        let missing = limits.itemSize - (upper - lower)
        if missing > 0 {
            lower = max(0, lower - missing / 2)
            upper = min(count, upper + missing - missing / 2)
            lower = max(0, min(lower, upper - limits.itemSize))
            upper = min(count, max(upper, lower + limits.itemSize))
        }

        return lower..<upper
    }
}
