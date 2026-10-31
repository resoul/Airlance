import ChatHistory
import Foundation

enum ChatPollFixtures {
    private static let polls: [(String, [String])] = [
        ("Коли збираємось наступного разу?", ["У пʼятницю ввечері", "У суботу вдень", "Наступного тижня", "Пропущу 🙈"]),
        ("Яку тему темної теми залишаємо?", ["Глибокий синій", "Графіт", "Чистий чорний"]),
        ("Що замовляємо на обід?", ["Піца 🍕", "Суші 🍣", "Бургери 🍔", "Салати 🥗"]),
        ("Оновлення вже встановили?", ["Так, усе працює", "Так, але є баги", "Ще ні"]),
    ]

    private static let quizzes: [(String, [String], Int, String)] = [
        (
            "Яке найглибше озеро у світі?",
            ["Байкал", "Танганьїка", "Каспійське море", "Верхнє"],
            0,
            "Байкал — до 1642 м глибини, він же найстаріше озеро на Землі."
        ),
        (
            "Скільки біт в одному байті?",
            ["4", "8", "16"],
            1,
            "Байт — це 8 біт, тому значень 256: від 0 до 255."
        ),
    ]

    static func decorate(_ messages: inout [HistoryMessage], chat: ChatSummary) {
        guard chat.kind != .person, messages.count > 12 else {
            return
        }

        var random = SeededRandom(seed: ChatHistoryFixtures.seed("polls:\(chat.id)"))
        let targets = [messages.count - 7, messages.count / 2, messages.count - 4]
        for (order, target) in targets.enumerated() {
            guard let index = candidate(near: target, in: messages) else {
                continue
            }

            var poll = order == 2 ? quiz(chat: chat, random: &random) : poll(chat: chat, random: &random)
            if order == 0, chat.kind == .group {
                poll.closeDate = Date().addingTimeInterval(180)
            }
            messages[index].content = .poll(poll)
            messages[index].entities = []
        }
    }

    private static func candidate(near target: Int, in messages: [HistoryMessage]) -> Int? {
        messages.indices.first { index in
            let message = messages[index]
            guard index >= target, index < messages.count - 2, case .text = message.content else {
                return false
            }

            return message.reply == nil && message.link == nil && message.forward == nil
        }
    }

    private static func poll(chat: ChatSummary, random: inout SeededRandom) -> MessagePoll {
        let pick = polls[Int(random.next() % UInt64(polls.count))]
        let multiple = random.next() % 3 == 0
        let voters = chat.kind == .channel ? 200 + Int(random.next() % 4000) : 2 + Int(random.next() % 6)
        var options = pick.1.map { text in
            MessagePoll.Option(text: text)
        }
        let isAnonymous = chat.kind == .channel || random.next() % 2 == 0
        vote(voters, in: &options, named: !isAnonymous, random: &random)
        var poll = MessagePoll(
            question: pick.0,
            options: options,
            isAnonymous: isAnonymous,
            allowsMultiple: multiple,
            voters: voters
        )
        if random.next() % 4 == 0 {
            poll.vote([Int(random.next() % UInt64(options.count))], by: Reactions.me)
        }

        return poll
    }

    private static func quiz(chat: ChatSummary, random: inout SeededRandom) -> MessagePoll {
        let pick = quizzes[Int(random.next() % UInt64(quizzes.count))]
        let voters = chat.kind == .channel ? 500 + Int(random.next() % 3000) : 3 + Int(random.next() % 5)
        var options = pick.1.map { text in
            MessagePoll.Option(text: text)
        }
        let isAnonymous = chat.kind == .channel
        vote(voters, in: &options, named: !isAnonymous, random: &random)
        var poll = MessagePoll(
            question: pick.0,
            options: options,
            isAnonymous: isAnonymous,
            allowsMultiple: false,
            voters: voters
        )
        poll.correctOption = pick.2
        poll.explanation = pick.3

        return poll
    }

    private static func vote(
        _ voters: Int,
        in options: inout [MessagePoll.Option],
        named: Bool,
        random: inout SeededRandom
    ) {
        let people = ChatChannelFixtures.commenters
        for voter in 0..<voters {
            let index = Int(random.next() % UInt64(options.count))
            options[index].votes += 1
            if named, voter < people.count {
                options[index].voters.append(people[voter])
            }
        }
    }
}
