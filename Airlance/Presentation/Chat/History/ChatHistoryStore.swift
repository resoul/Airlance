import ChatHistory
import Foundation
import Observers

struct IncomingMessage: Sendable {
    let chatID: String
    let message: HistoryMessage
}

@MainActor
final class ChatHistoryStore: HistorySource {
    let chatsStore: ChatsStore
    let fixtureSalt: Int
    var histories: [String: ChatHistoryFixtures.History] = [:]
    var liveCount = 0
    var demoTasks: [String: Task<Void, Never>] = [:]
    var feedTask: Task<Void, Never>?
    var scheduled: [String: [ScheduledMessage]] = [:]
    var scheduleTasks: [String: Task<Void, Never>] = [:]
    var translations: [String: [String: MessageTranslation]] = [:]
    var revealedSpoilers: [String: Set<String>] = [:]
    private var viewers: [String: Set<UUID>] = [:]
    private(set) var isShutDown = false

    private let observers = ObserverList<HistoryEvent>()
    private let incoming = ObserverList<IncomingMessage>()
    private var sentCount = 0

    init(chatsStore: ChatsStore, fixtureSalt: Int = 0) {
        self.chatsStore = chatsStore
        self.fixtureSalt = fixtureSalt
    }

    func history(for id: String) -> ChatHistoryFixtures.History? {
        if let history = histories[id] {
            return history
        }

        guard let chat = chatsStore.chat(id) else {
            return threadHistory(id)
        }

        let history = ChatHistoryFixtures.history(for: chat, salt: fixtureSalt)
        histories[id] = history

        return history
    }

    func slice(_ request: HistoryRequest, in chatID: String) async -> HistorySlice {
        guard let history = history(for: chatID) else {
            return .empty
        }

        let messages = history.messages
        let range = Self.range(of: request, in: messages)
        let pinned = history.pinnedIDs.compactMap { id in
            messages.last { message in
                message.id == id
            }
        }

        return HistorySlice(
            messages: Array(messages[range]),
            hasOlder: range.lowerBound > 0,
            hasNewer: range.upperBound < messages.count,
            unreadFrom: history.unreadFrom,
            pinned: pinned
        )
    }

    func messageCount(in chatID: String) -> Int {
        histories[chatID]?.messages.count ?? 0
    }

    func observeHistory(_ onEvent: @escaping @MainActor @Sendable (HistoryEvent) -> Void) -> ObservationToken {
        observers.add(onEvent)
    }

    private static func range(of request: HistoryRequest, in messages: [HistoryMessage]) -> Range<Int> {
        switch request {
        case .latest(let count):
            return max(0, messages.count - count)..<messages.count
        case .around(let id, let before, let after):
            guard let index = messages.firstIndex(where: { message in
                message.id == id
            }) else {
                return max(0, messages.count - before - after - 1)..<messages.count
            }

            return max(0, index - before)..<min(messages.count, index + after + 1)
        }
    }

    func append(_ message: HistoryMessage, to id: String) {
        guard !isShutDown, history(for: id) != nil else {
            return
        }

        histories[id]?.messages.append(message)
        observers.notify(HistoryEvent(chatID: id, appended: [message]))
    }

    func receive(_ message: HistoryMessage, in id: String) {
        guard !isShutDown else {
            return
        }

        append(message, to: id)
        let isOpen = isViewed(id)
        chatsStore.recordIncoming(message, in: id, countsUnread: !isOpen)
        if !isOpen {
            incoming.notify(IncomingMessage(chatID: id, message: message))
        }
    }

    func isViewed(_ id: String) -> Bool {
        !(viewers[id]?.isEmpty ?? true)
    }

    func view(_ id: String) -> ObservationToken {
        let token = UUID()
        viewers[id, default: []].insert(token)
        watchPollDeadlines(in: id)
        if viewers[id]?.count == 1 {
            startDemo(for: id)
        }

        return ObservationToken { [weak self] in
            Task { @MainActor in
                self?.endView(id, token: token)
            }
        }
    }

    func shutdown() async {
        isShutDown = true
        scheduleTasks.values.forEach { task in
            task.cancel()
        }
        scheduleTasks = [:]
        let tasks = Array(demoTasks.values) + (feedTask.map { task in
            [task]
        } ?? [])
        for task in tasks {
            task.cancel()
        }
        demoTasks = [:]
        feedTask = nil
        viewers = [:]
        for task in tasks {
            await task.value
        }
    }

    private func endView(_ id: String, token: UUID) {
        viewers[id]?.remove(token)
        if !isViewed(id) {
            viewers[id] = nil
            stopDemo(for: id)
        }
    }

    func observeIncoming(_ onMessage: @escaping @MainActor @Sendable (IncomingMessage) -> Void) -> ObservationToken {
        incoming.add(onMessage)
    }

    func send(
        _ text: String,
        to id: String,
        replyTo: HistoryMessage? = nil,
        quote: MessageQuote? = nil,
        options: SendOptions = SendOptions()
    ) {
        let url = Self.firstLink(in: text)
        let link = url.map { url in
            MessageLink(url: url)
        }
        let reply = replyTo.map { message in
            MessageReply(message, quote: quote)
        }
        var message = outgoing(.text(text), in: id, reply: reply, link: link)
        message.entities = MessageEntity.valid(options.entities, in: text)
        message.isSilent = options.isSilent
        post(message, to: id)
        if let url {
            loadPreview(url, messageID: message.id, chatID: id)
        }
    }

    func forward(_ source: HistoryMessage, authorName: String, to id: String) {
        let origin = source.forward ?? MessageForward(fromID: source.authorID, fromName: authorName)
        var link = source.link
        if link?.preview == nil, let url = link?.url {
            link?.preview = ChatLinkFixtures.preview(for: url)
        }
        var message = outgoing(source.content, in: id, reply: nil, link: link)
        message.forward = origin
        post(message, to: id)
    }

    func outgoing(
        _ content: MessageContent,
        in id: String,
        reply: MessageReply?,
        link: MessageLink?
    ) -> HistoryMessage {
        sentCount += 1

        return HistoryMessage(
            id: "\(id)-out-\(sentCount)",
            authorID: "me",
            authorName: "",
            isOutgoing: true,
            date: Date(),
            content: content,
            delivery: .sending,
            reply: reply,
            link: link
        )
    }

    func post(_ message: HistoryMessage, to id: String) {
        guard history(for: id) != nil else {
            return
        }

        let message = channelPost(message, in: id)
        append(message, to: id)
        countComment(message, in: id)
        let text = ChatsStore.preview(of: message)
        chatsStore.recordOutgoing(text, date: message.date, in: id)
        deliver(message, in: id)
    }

    func setPinned(_ isPinned: Bool, messageID: String, in id: String) {
        guard let history = history(for: id) else {
            return
        }

        var pins = history.pinnedIDs.filter { pin in
            pin != messageID
        }
        if isPinned {
            pins.append(messageID)
            let order = Dictionary(uniqueKeysWithValues: history.messages.enumerated().map { index, message in
                (message.id, index)
            })
            pins.sort { lhs, rhs in
                (order[lhs] ?? 0) < (order[rhs] ?? 0)
            }
        }
        histories[id]?.pinnedIDs = pins
        var appended: [HistoryMessage] = []
        if isPinned, let message = history.messages.first(where: { message in
            message.id == messageID
        }) {
            appended.append(postService(.pinned(MessageReply(message)), in: id))
        }
        observers.notify(HistoryEvent(chatID: id, appended: appended))
    }

    func changed(_ id: String) {
        observers.notify(HistoryEvent(chatID: id))
    }

    func delete(_ messageID: String, from id: String) {
        guard history(for: id) != nil else {
            return
        }

        histories[id]?.messages.removeAll { message in
            message.id == messageID
        }
        histories[id]?.pinnedIDs.removeAll { pin in
            pin == messageID
        }
        observers.notify(HistoryEvent(chatID: id, removed: [messageID]))
    }

    func update(_ messageID: String, in id: String, change: (inout HistoryMessage) -> Void) {
        guard !isShutDown, let index = histories[id]?.messages.firstIndex(where: { message in
            message.id == messageID
        }) else {
            return
        }

        if var message = histories[id]?.messages[index] {
            change(&message)
            histories[id]?.messages[index] = message
        }
        observers.notify(HistoryEvent(chatID: id))
    }
}
