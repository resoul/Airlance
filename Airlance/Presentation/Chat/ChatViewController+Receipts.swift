import ChatHistory
import Foundation

extension ChatViewController {
    func menuReceipts(for message: HistoryMessage) -> MessageMenuReceipts? {
        let chat = thread == nil ? dependencies.chatsStore.chat(id) : nil
        guard let receipts = ChatReceiptFixtures.receipts(for: message, chat: chat) else {
            return nil
        }

        let strings = presentation.strings
        let time = DateFormatter()
        time.locale = strings.pack.locale
        time.setLocalizedDateFormatFromTemplate("jmm")
        if let readAt = receipts.readAt {
            let summary = strings.chatReceiptsReadAt(time.string(from: readAt))

            return MessageMenuReceipts(summary: summary, symbol: "checkmark", avatars: [], rows: [])
        }

        let rows = receipts.people.map { person in
            MessageMenuReceipts.Row(
                person: person.commenter,
                detail: person.readAt.map { date in
                    strings.chatReceiptsReadAt(time.string(from: date))
                },
                reaction: person.reaction
            )
        }

        return MessageMenuReceipts(
            summary: summary(receipts),
            symbol: receipts.reactionCount > 0 ? "heart" : "checkmark",
            avatars: receipts.people.prefix(3).map(\.commenter),
            rows: rows
        )
    }

    private func summary(_ receipts: MessageReceipts) -> String {
        let strings = presentation.strings
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
