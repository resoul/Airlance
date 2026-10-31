import ChatHistory
import Foundation

enum ChatHistoryFixtures {
    struct History {
        var messages: [HistoryMessage]
        let unreadFrom: String?
        var pinnedIDs: [String] = []
    }

    private struct Entry {
        let author: Author
        let content: MessageContent
        var link: MessageLink?
        let date: Date
    }

    private struct Author {
        let id: String
        let name: String
        let isMe: Bool
    }

    private static let photoSizes = [(1280, 960), (960, 1280), (1280, 720), (1080, 1080), (720, 1280), (1600, 900)]
    private static let captions = [
        "Як тобі вид? 🏔️",
        "Вчорашній вечір",
        "Ось що вийшло",
        "Фото з вихідних, як і обіцяв",
        "Глянь, яке світло було зранку — майже не обробляв",
    ]
    private static let me = Author(id: "me", name: "", isMe: true)
    private static let groupMembers = [
        Author(id: "vika", name: "Віка", isMe: false),
        Author(id: "anna", name: "Анна", isMe: false),
        Author(id: "boris", name: "Борис", isMe: false),
        Author(id: "olena", name: "Олена", isMe: false),
    ]
    private static let phrases = [
        "Привіт! Як ти?",
        "Все добре, дякую 🙂",
        "Глянув білд, таббар тепер набагато плавніший",
        "Ок",
        "Давай завтра зранку зідзвонимося, я якраз закінчу з дизайном екрана профілю",
        "Супер!",
        "А ти бачив нові папки чатів? Здається, свайпи між ними тепер працюють майже як у системних застосунках",
        "Так, вже тестую",
        "Скинь, будь ласка, посилання",
        "Зараз",
        "Я буду хвилин за десять",
        "Дякую 🙏",
        "Подивись, коли буде час. Там кілька дрібниць з відступами і баг з клавіатурою на старих айфонах",
        "Добре, подивлюся ввечері",
        "Чудово 👍",
        "Ти сьогодні в офісі?",
        "Ні, працюю з дому",
        "Тоді наберу після обіду",
        "Окей, домовились",
        "Бачу, вже виправили",
        "Можна ще одне питання?",
        "Звісно",
        "Який шрифт ми зараз використовуємо в заголовках?",
        "Montserrat",
        "Зрозумів, дякую",
        "Ха-ха, класно вийшло 😄",
        "Нагадай мені в пʼятницю про звіт",
        "Нагадаю",
        "Вибач, не встиг відповісти — був на зустрічі",
        "Нічого страшного",
    ]

    static func history(for chat: ChatSummary, salt: Int = 0) -> History {
        var random = SeededRandom(seed: seed(salt == 0 ? chat.id : "\(salt):\(chat.id)"))
        let authors = authors(for: chat)
        let count = ChatStressFixtures.count(for: chat.id) ?? 90 + Int(random.next() % 60)
        let last = last(chat, authors: authors)
        var reversed: [Entry] = [Entry(author: last.author, content: .text(last.text), date: last.date)]
        var author = reversed[0].author
        var date = chat.date
        for index in 1..<count {
            date -= gap(&random)
            let forcesIncoming = index < chat.unread
            if forcesIncoming || random.next() % 10 < 4 {
                author = pick(authors, excludingMe: forcesIncoming, random: &random)
            }
            reversed.append(entry(index: index, chatID: chat.id, author: author, date: date, random: &random))
        }

        var messages = reversed.reversed().enumerated().map { index, entry in
            message(chat: chat, index: index, isLast: index == count - 1, entry: entry)
        }
        decorate(&messages, random: &random)
        let unreadFrom = chat.unread > 0 ? messages[max(0, count - chat.unread)].id : nil
        let pinnedIDs = pins(in: messages, random: &random)
        ChatServiceFixtures.decorate(&messages, chat: chat, pinnedIDs: pinnedIDs, random: &random)
        ChatReactionFixtures.decorate(&messages, chat: chat, random: &random)

        return History(messages: messages, unreadFrom: unreadFrom, pinnedIDs: pinnedIDs)
    }

    static func incoming(for chat: ChatSummary, index: Int, date: Date, replyTo: HistoryMessage?) -> HistoryMessage {
        let candidates = authors(for: chat).filter { author in
            !author.isMe
        }
        let author = candidates.randomElement() ?? Author(id: chat.id, name: chat.name, isMe: false)
        var message = HistoryMessage(
            id: "\(chat.id)-live-\(index)",
            authorID: author.id,
            authorName: author.name,
            isOutgoing: false,
            date: date,
            content: .text(phrases.randomElement() ?? "👋")
        )
        let roll = Int.random(in: 0..<10)
        if roll < 3 {
            var link = ChatLinkFixtures.text(site: Int.random(in: 0..<100), template: Int.random(in: 0..<100))
            link.link.preview = nil
            message.content = .text(link.text)
            message.link = link.link
        } else if roll < 5, let replyTo {
            message.reply = MessageReply(replyTo)
        }

        return message
    }

    private static func message(
        chat: ChatSummary,
        index: Int,
        isLast: Bool,
        entry: Entry
    ) -> HistoryMessage {
        let delivery: DeliveryState = isLast && chat.outgoingRead == false ? .delivered : .read
        var message = HistoryMessage(
            id: "\(chat.id)-\(index)",
            authorID: entry.author.id,
            authorName: entry.author.name,
            isOutgoing: entry.author.isMe,
            date: entry.date,
            content: entry.content,
            delivery: delivery,
            link: entry.link
        )
        if case .voice = entry.content, !entry.author.isMe, index % 3 == 0 {
            message.isListened = false
        }

        return message
    }

    private static func entry(
        index: Int,
        chatID: String,
        author: Author,
        date: Date,
        random: inout SeededRandom
    ) -> Entry {
        let roll = random.next() % 100
        if roll >= 13, roll < 17 {
            let content = ChatFileFixtures.file(pick: Int(random.next() % 100), isOutgoing: author.isMe)

            return Entry(author: author, content: content, date: date)
        }
        if roll >= 17, roll < 20 {
            return Entry(author: author, content: ChatFileFixtures.location(pick: Int(random.next() % 100)), date: date)
        }
        if roll >= 6, roll < 13 {
            return Entry(author: author, content: ChatVoiceFixtures.voice(pick: Int(random.next() % 100)), date: date)
        }
        guard roll < 6 else {
            return Entry(author: author, content: content(index: index, chatID: chatID, random: &random), date: date)
        }

        let link = ChatLinkFixtures.text(site: Int(random.next() % 100), template: Int(random.next() % 100))

        return Entry(author: author, content: .text(link.text), link: link.link, date: date)
    }

    private static func pins(in messages: [HistoryMessage], random: inout SeededRandom) -> [String] {
        let count = Int(random.next() % 4)
        let candidates = messages.dropLast(3).filter { message in
            guard case .text = message.content else {
                return false
            }

            return true
        }
        guard count > 0, candidates.count > count else {
            return []
        }

        let step = candidates.count / count

        return (0..<count).map { index in
            candidates[index * step + Int(random.next() % UInt64(max(1, step)))].id
        }
    }

    private static func decorate(_ messages: inout [HistoryMessage], random: inout SeededRandom) {
        let sources = ChatLinkFixtures.forwardSources
        for index in messages.indices.dropFirst(4) {
            let roll = random.next() % 100
            if roll < 9 {
                let target = max(0, index - 1 - Int(random.next() % 6))
                messages[index].reply = MessageReply(messages[target])
            } else if roll < 13 {
                messages[index].forward = sources[Int(random.next() % UInt64(sources.count))]
            }
        }
    }

    private static func content(index: Int, chatID: String, random: inout SeededRandom) -> MessageContent {
        guard random.next() % 100 < 14 else {
            return .text(phrases[Int(random.next() % UInt64(phrases.count))])
        }

        let roll = random.next() % 10
        let count = roll < 5 ? 1 : (roll < 8 ? 2 + Int(random.next() % 3) : 5 + Int(random.next() % 6))
        let photos = (0..<count).map { photo in
            let id = "\(chatID)-\(index)-\(photo)"
            if random.next() % 4 == 0 {
                return ChatVideoFixtures.video(id: id, pick: Int(random.next() % 100))
            }

            let size = photoSizes[Int(random.next() % UInt64(photoSizes.count))]

            return ChatVideoFixtures.photo(id: id, size: size, seed: Int(random.next() % 1000))
        }
        let caption = random.next() % 2 == 0 ? captions[Int(random.next() % UInt64(captions.count))] : ""

        return .photos(photos, caption: caption)
    }

    private static func authors(for chat: ChatSummary) -> [Author] {
        switch chat.kind {
        case .person:
            [Author(id: chat.id, name: chat.name, isMe: false), me]
        case .group:
            groupMembers + [me]
        case .channel:
            [Author(id: chat.id, name: chat.name, isMe: false)]
        }
    }

    private static func last(_ chat: ChatSummary, authors: [Author]) -> (author: Author, text: String, date: Date) {
        let mine = ChatSummary.outgoingPrefix
        if chat.message.hasPrefix(mine), authors.contains(where: \.isMe) {
            return (me, String(chat.message.dropFirst(mine.count)), chat.date)
        }

        if chat.kind == .group, let range = chat.message.range(of: ": ") {
            let name = String(chat.message[..<range.lowerBound])
            let author = groupMembers.first { member in
                member.name == name
            } ?? Author(id: name, name: name, isMe: false)

            return (author, String(chat.message[range.upperBound...]), chat.date)
        }

        return (authors[0], chat.message, chat.date)
    }

    private static func pick(_ authors: [Author], excludingMe: Bool, random: inout SeededRandom) -> Author {
        let candidates = excludingMe ? authors.filter { author in
            !author.isMe
        } : authors

        return candidates[Int(random.next() % UInt64(candidates.count))]
    }

    private static func gap(_ random: inout SeededRandom) -> TimeInterval {
        let roll = random.next() % 100
        let unit = Double(random.next() % 1000) / 1000
        if roll < 70 {
            return 20 + unit * 200
        }

        if roll < 95 {
            return 600 + unit * 4800
        }

        return 6 * 3600 + unit * 14 * 3600
    }

    static func seed(_ id: String) -> UInt64 {
        id.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { hash, scalar in
            (hash ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
    }
}

struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB

        return value ^ (value >> 31)
    }
}
