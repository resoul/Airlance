import ChatHistory
import Foundation

extension ChatViewController {
    func menuReceipts(for message: HistoryMessage) -> MessageMenuReceipts? {
        let chat = thread == nil ? dependencies.chatsStore.chat(id) : nil
        let receipts = ChatReceiptFixtures.receipts(for: message, chat: chat)
        guard receipts != nil || !message.videoReactions.isEmpty else {
            return nil
        }

        let time = DateFormatter()
        time.locale = presentation.strings.pack.locale
        time.setLocalizedDateFormatFromTemplate("jmm")
        let rows = Self.withVideos(rows(receipts, time: time), videos: message.videoReactions)
        var menu = MessageMenuReceipts(
            summary: summary(receipts, videos: message.videoReactions.count, time: time),
            symbol: symbol(receipts, hasVideos: !message.videoReactions.isEmpty),
            avatars: receipts?.readAt != nil ? [] : rows.prefix(3).map(\.person),
            rows: rows
        )
        menu.onVideo = { [weak self] reactionID in
            self?.showVideoReaction(reactionID, messageID: message.id)
        }

        return menu
    }

    private func rows(_ receipts: MessageReceipts?, time: DateFormatter) -> [MessageMenuReceipts.Row] {
        let strings = presentation.strings

        return (receipts?.people ?? []).map { person in
            MessageMenuReceipts.Row(
                person: person.commenter,
                detail: person.readAt.map { date in
                    strings.chatReceiptsReadAt(time.string(from: date))
                },
                reaction: person.reaction
            )
        }
    }

    private static func withVideos(
        _ rows: [MessageMenuReceipts.Row],
        videos: [MessageVideoReaction]
    ) -> [MessageMenuReceipts.Row] {
        var rows = rows
        var added: [MessageMenuReceipts.Row] = []
        for video in videos.reversed() {
            if let index = rows.firstIndex(where: { row in
                row.person.id == video.author.id && row.video == nil
            }) {
                var row = rows.remove(at: index)
                row.video = video
                added.append(row)
            } else {
                var row = MessageMenuReceipts.Row(person: video.author, detail: nil, reaction: nil)
                row.video = video
                added.append(row)
            }
        }

        return added + rows
    }

    private func symbol(_ receipts: MessageReceipts?, hasVideos: Bool) -> String {
        if let receipts, receipts.reactionCount > 0 {
            return "heart"
        }

        return hasVideos && receipts?.readAt == nil ? "video" : "checkmark"
    }

    private func summary(_ receipts: MessageReceipts?, videos: Int, time: DateFormatter) -> String {
        let strings = presentation.strings
        if let readAt = receipts?.readAt {
            return strings.chatReceiptsReadAt(time.string(from: readAt))
        }

        guard let receipts, receipts.readCount > 0 || receipts.reactionCount > 0 else {
            return strings.count(
                videos,
                one: strings.chatReceiptsVideosOne,
                few: strings.chatReceiptsVideosFew,
                many: strings.chatReceiptsVideosMany
            )
        }

        guard receipts.reactionCount > 0 else {
            return strings.count(
                receipts.readCount,
                one: strings.chatReceiptsSeenOne,
                few: strings.chatReceiptsSeenFew,
                many: strings.chatReceiptsSeenMany
            )
        }

        return strings.count(
            receipts.reactionCount,
            one: strings.chatReceiptsReactionsOne,
            few: strings.chatReceiptsReactionsFew,
            many: strings.chatReceiptsReactionsMany
        )
    }
}
