import ChatHistory
import Foundation

extension ChatHistoryStore {
    private static let demoInterval: ClosedRange<TimeInterval> = 8...16
    private static let feedInterval: ClosedRange<TimeInterval> = 20...40
    private static let previewDelay: ClosedRange<TimeInterval> = 1...2
    private static let readDelay: ClosedRange<TimeInterval> = 2...4

    func startDemo(for id: String) {
        stopDemo(for: id)
        guard !isShutDown else {
            return
        }

        demoTasks[id] = Task { [weak self] in
            while !Task.isCancelled {
                let interval = ChatStressFixtures.isStress(id) ? ChatStressFixtures.feedInterval : Self.demoInterval
                let delay = Double.random(in: interval)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else {
                    return
                }

                self?.deliverDemo(to: id)
            }
        }
    }

    func stopDemo(for id: String) {
        demoTasks.removeValue(forKey: id)?.cancel()
    }

    private func deliverDemo(to id: String) {
        guard let chat = chatsStore.chat(id) else {
            return
        }

        liveCount += 1
        let message = ChatHistoryFixtures.incoming(
            for: chat,
            index: liveCount,
            date: Date(),
            replyTo: histories[id]?.messages.last
        )
        receive(message, in: id)
        if let link = message.link, link.preview == nil {
            loadPreview(link.url, messageID: message.id, chatID: id)
        }
    }

    func deliver(_ message: HistoryMessage, in id: String) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.update(message.id, in: id) { message in
                message.delivery = .delivered
            }
            let delay = Double.random(in: Self.readDelay)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.update(message.id, in: id) { message in
                message.delivery = .read
            }
            guard let self, !self.isShutDown else {
                return
            }

            self.chatsStore.markOutgoingRead(id, date: message.date)
        }
    }

    static func firstLink(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)

        return detector?.firstMatch(in: text, range: range)?.url?.absoluteString
    }

    func loadPreview(_ url: String, messageID: String, chatID: String) {
        Task { [weak self] in
            let delay = Double.random(in: Self.previewDelay)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let preview = ChatLinkFixtures.preview(for: url) else {
                return
            }

            self?.update(messageID, in: chatID) { message in
                message.link?.preview = preview
            }
        }
    }

    func startFeed() {
        feedTask?.cancel()
        guard !isShutDown else {
            return
        }

        feedTask = Task { [weak self] in
            while !Task.isCancelled {
                let delay = Double.random(in: Self.feedInterval)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else {
                    return
                }

                self?.deliverFeed()
            }
        }
    }

    private func deliverFeed() {
        let candidates = chatsStore.chats.filter { chat in
            chat.kind != .channel && !chat.isArchived && !chat.isMuted && !isViewed(chat.id)
        }
        guard let chat = candidates.randomElement() else {
            return
        }

        liveCount += 1
        var message = ChatHistoryFixtures.incoming(for: chat, index: liveCount, date: Date(), replyTo: nil)
        while message.link != nil {
            message = ChatHistoryFixtures.incoming(for: chat, index: liveCount, date: Date(), replyTo: nil)
        }
        receive(message, in: chat.id)
    }
}
