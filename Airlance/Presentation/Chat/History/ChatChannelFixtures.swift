import ChatHistory
import Foundation

enum ChatChannelFixtures {
    private static let discussionGroups = ["news": "news-chat"]
    static let commenters = [
        MessageCommenter(id: "vika", name: "Віка"),
        MessageCommenter(id: "anna", name: "Анна"),
        MessageCommenter(id: "boris", name: "Борис"),
        MessageCommenter(id: "olena", name: "Олена"),
        MessageCommenter(id: "oleg", name: "Олег"),
        MessageCommenter(id: "natalia", name: "Наталя"),
        MessageCommenter(id: "andrii", name: "Андрій"),
        MessageCommenter(id: "maks", name: "Макс"),
    ]
    private static let signatures = ["Віка", "Олег Мельник", "Редакція"]
    private static let phrases = [
        "Нарешті! Давно чекав 🔥",
        "А коли в релізі?",
        "Дякую, корисно",
        "Не згоден, як на мене попередній варіант був кращим",
        "Тестую вже другий день — поки все стабільно",
        "+1",
        "Можна детальніше про другий пункт?",
        "Ого, не знав",
        "Скиньте, будь ласка, посилання на джерело",
        "Класно вийшло 👏",
        "У мене на старому айфоні трохи підвисає, але загалом ок",
        "Підписуюсь під кожним словом",
        "Чекаємо продовження!",
        "Хтось вже пробував?",
    ]

    static func discussionGroup(of channelID: String) -> String? {
        discussionGroups[channelID]
    }

    static func channel(discussedIn groupID: String) -> String? {
        discussionGroups.first { _, group in
            group == groupID
        }?.key
    }

    static func decorate(_ messages: inout [HistoryMessage], chat: ChatSummary, random: inout SeededRandom) {
        guard chat.kind == .channel else {
            return
        }

        let audience = max(100, chat.memberCount)
        for index in messages.indices where !messages[index].content.isService {
            let reach = 30 + Int(random.next() % 70)
            messages[index].views = audience * reach / 100
            if random.next() % 10 < 3 {
                messages[index].signature = signatures[Int(random.next() % UInt64(signatures.count))]
            }
            messages[index].comments = comments(random: &random)
        }
    }

    static func thread(for post: HistoryMessage, in chat: ChatSummary) -> ChatHistoryFixtures.History {
        let thread = CommentThread(channelID: chat.id, postID: post.id)
        var random = SeededRandom(seed: ChatHistoryFixtures.seed(thread.id))
        var messages = header(for: post, thread: thread, in: chat)
        let recent = post.comments?.recent ?? []
        let total = post.comments?.total ?? 0
        var date = post.date
        for index in 0..<total {
            date += 30 + Double(random.next() % 1800)
            let fromEnd = total - 1 - index
            let fallback = commenters[Int(random.next() % UInt64(commenters.count))]
            let author = fromEnd < recent.count ? recent[fromEnd] : fallback
            var comment = HistoryMessage(
                id: "\(thread.id)-\(index)",
                authorID: author.id,
                authorName: author.name,
                isOutgoing: false,
                date: min(date, Date()),
                content: .text(phrases[Int(random.next() % UInt64(phrases.count))])
            )
            if index > 2, random.next() % 10 < 2 {
                comment.reply = MessageReply(messages[messages.count - 1 - Int(random.next() % 3)])
            }
            messages.append(comment)
        }

        return ChatHistoryFixtures.History(messages: messages, unreadFrom: nil)
    }

    static func discussion(
        posts: [HistoryMessage],
        threads: (HistoryMessage) -> [HistoryMessage],
        group: String,
        channel: ChatSummary
    ) -> ChatHistoryFixtures.History {
        var messages: [HistoryMessage] = []
        for post in posts where !post.content.isService {
            var copy = HistoryMessage(
                id: discussionPostID(post.id, group: group),
                authorID: channel.id,
                authorName: channel.name,
                isOutgoing: false,
                date: post.date,
                content: post.content,
                link: post.link
            )
            copy.forward = MessageForward(fromID: channel.id, fromName: channel.name)
            messages.append(copy)
            messages += threads(post).map { comment in
                discussionComment(comment, post: copy)
            }
        }
        messages.sort { lhs, rhs in
            lhs.date < rhs.date
        }

        return ChatHistoryFixtures.History(messages: messages, unreadFrom: nil)
    }

    static func discussionPostID(_ postID: String, group: String) -> String {
        "\(group)-post-\(postID)"
    }

    static func discussionComment(_ comment: HistoryMessage, post: HistoryMessage) -> HistoryMessage {
        var comment = comment
        if comment.reply == nil {
            comment.reply = MessageReply(post)
        }

        return comment
    }

    static func isComment(_ message: HistoryMessage, in thread: CommentThread) -> Bool {
        !message.content.isService && message.id != thread.id + "-post"
    }

    private static func header(
        for post: HistoryMessage,
        thread: CommentThread,
        in chat: ChatSummary
    ) -> [HistoryMessage] {
        var copy = HistoryMessage(
            id: thread.id + "-post",
            authorID: chat.id,
            authorName: chat.name,
            isOutgoing: false,
            date: post.date,
            content: post.content,
            link: post.link
        )
        copy.views = post.views
        copy.signature = post.signature
        let started = HistoryMessage(
            id: thread.id + "-started",
            authorID: "",
            authorName: "",
            isOutgoing: false,
            date: post.date,
            content: .service(.discussionStarted)
        )

        return [copy, started]
    }

    private static func comments(random: inout SeededRandom) -> MessageComments {
        let total = random.next() % 5 == 0 ? 0 : 1 + Int(random.next() % 60)
        var recent: [MessageCommenter] = []
        while recent.count < min(3, total) {
            let pick = commenters[Int(random.next() % UInt64(commenters.count))]
            if !recent.contains(pick) {
                recent.append(pick)
            }
        }

        return MessageComments(total: total, recent: recent)
    }
}
