import ChatHistory
import CoreGraphics

struct AvatarSeries: Sendable {
    let id: String
    let authorID: String
    let authorName: String
    let firstRow: Int
    let topInset: CGFloat
    var lastRow: Int
    var bottomInset: CGFloat
}

struct AvatarSeriesBuilder {
    private(set) var result: [AvatarSeries] = []
    private var isOpen = false

    mutating func add(_ message: HistoryMessage, grouping: HistoryGrouping, row: Int, layout: MessageBubbleLayout) {
        if !isOpen || !grouping.joinedTop {
            result.append(
                AvatarSeries(
                    id: message.id,
                    authorID: message.authorID,
                    authorName: message.authorName,
                    firstRow: row,
                    topInset: layout.bubbleFrame.minY,
                    lastRow: row,
                    bottomInset: layout.bubbleFrame.maxY
                )
            )
        } else if let last = result.indices.last {
            result[last].lastRow = row
            result[last].bottomInset = layout.bubbleFrame.maxY
        }
        isOpen = grouping.joinedBottom
    }
}
