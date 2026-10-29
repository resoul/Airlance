import Foundation

enum ChatFixtures {
    private static let nonContacts: Set<String> = ["max", "lucia", "taras"]
    private static let archived: Set<String> = ["music", "sport", "neighbors"]

    static func make(now: Date, variant: Int = 0) -> [ChatSummary] {
        let chats = all(now: now)
        guard variant > 0 else {
            return chats
        }

        return chats.enumerated().compactMap { index, chat in
            guard !ChatStressFixtures.isStress(chat.id), (index + variant) % 2 == 0 else {
                return nil
            }

            var chat = chat
            chat.unread = (chat.unread + variant * 3) % 9
            chat.isPinned = false

            return chat
        }
    }

    private static func all(now: Date) -> [ChatSummary] {
        let minute: TimeInterval = 60
        let hour = 60 * minute
        let day = 24 * hour

        let chats = [
            person("anna", "Анна", "Добре, тоді до завтра 👋", now - 5 * minute, unread: 2, online: true, pinned: true),
            group("team", "Airlance Team", "Віка: виклала новий білд, перевірте таббар", now - 12 * minute, unread: 14),
            group("stress", "Стрес-тест · 30 000", "Анна: Ок", now - 20 * minute, unread: 40),
            person("boris", "Борис", "Скинь, будь ласка, фото з вихідних", now - 40 * minute, read: true),
            channel("news", "Airlance News", "Папки чатів уже в тестовій збірці", now - 2 * hour, unread: 3),
            person("vika", "Віка", "Голосове повідомлення", now - 3 * hour, online: true),
            group("family", "Сімʼя", "Мама: не забудь купити хліб", now - 5 * hour, unread: 1, muted: true),
            person("max", "Max", "See you at the meetup!", now - 7 * hour, read: false),
            channel("design", "Design Daily", "10 ідей для порожніх станів у застосунках", now - 1 * day, muted: true),
            person("lucia", "Lucía", "¡Gracias! Te llamo luego", now - 1 * day - 2 * hour),
            group("football", "Футбол", "Олег: хто сьогодні грає?", now - day - 5 * hour, unread: 27, muted: true),
            person("olena", "Олена", "Фото", now - 2 * day, read: true),
            person("dmytro", "Дмитро", "Дякую, все отримав", now - 2 * day - 3 * hour),
            channel("tech", "Tech Digest", "Swift 6: що змінилося в конкурентності", now - 3 * day, unread: 8),
            group("work", "Робочий чат", "Ти: завтра стендап о 10:00", now - 3 * day - 4 * hour, read: true),
            person("ira", "Ірина", "Ок 👍", now - 4 * day),
            person("taras", "Тарас", "Подзвони, як будеш вільний", now - 5 * day, unread: 1),
            group("travel", "Подорож у Карпати", "Наталя: квитки куплені!", now - 6 * day),
            person("sofia", "Софія", "Ти: побачимося в суботу", now - 8 * day, read: false),
            channel("music", "Нова музика", "Плейлист тижня", now - 9 * day, muted: true),
            person("yurii", "Юрій", "Надіслав документи на пошту", now - 12 * day),
            group("neighbors", "Сусіди", "Андрій: завтра не буде води з 10 до 14", now - 14 * day, muted: true),
            person("kateryna", "Катерина", "Дуже дякую за допомогу!", now - 20 * day),
            person("pavlo", "Павло", "Стікер", now - 30 * day),
            channel("sport", "Спорт сьогодні", "Огляд матчів вихідних", now - 40 * day),
            person("marta", "Марта", "Ти: З днем народження! 🎉", now - 200 * day, read: true),
        ]

        return chats.map { chat in
            var chat = chat
            chat.isContact = !nonContacts.contains(chat.id)
            chat.isArchived = archived.contains(chat.id)

            return chat
        }
    }

    private static func person(
        _ id: String,
        _ name: String,
        _ message: String,
        _ date: Date,
        unread: Int = 0,
        online: Bool = false,
        pinned: Bool = false,
        read: Bool? = nil
    ) -> ChatSummary {
        ChatSummary(
            id: id,
            name: name,
            kind: .person,
            message: message,
            date: date,
            unread: unread,
            isPinned: pinned,
            outgoingRead: read,
            isOnline: online
        )
    }

    private static func group(
        _ id: String,
        _ name: String,
        _ message: String,
        _ date: Date,
        unread: Int = 0,
        muted: Bool = false,
        read: Bool? = nil
    ) -> ChatSummary {
        ChatSummary(
            id: id,
            name: name,
            kind: .group,
            message: message,
            date: date,
            unread: unread,
            isMuted: muted,
            outgoingRead: read
        )
    }

    private static func channel(
        _ id: String,
        _ name: String,
        _ message: String,
        _ date: Date,
        unread: Int = 0,
        muted: Bool = false
    ) -> ChatSummary {
        ChatSummary(id: id, name: name, kind: .channel, message: message, date: date, unread: unread, isMuted: muted)
    }
}
