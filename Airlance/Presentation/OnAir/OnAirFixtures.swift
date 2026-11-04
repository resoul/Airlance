import Foundation

enum OnAirFixtures {
    private typealias Row = (
        id: String, name: String, category: OnAirCategory, subscribers: Int, score: Int, boosts: Int,
        previousRank: Int?, growth: Int, ageDays: Int
    )

    private static let rows: [Row] = [
        ("swift-weekly", "Swift Weekly", .tech, 48_200, 9_840, 1_320, 1, 6, 900),
        ("world-5min", "Світ за 5 хвилин", .news, 212_000, 9_610, 1_870, 3, 14, 1_400),
        ("space-near", "Космос поруч", .science, 96_400, 8_920, 1_140, 2, 3, 760),
        ("design-daily", "Дизайн щодня", .design, 31_700, 7_450, 980, 5, 11, 540),
        ("kyiv-today", "Київ сьогодні", .news, 154_000, 7_120, 1_410, 4, 2, 2_100),
        ("ai-daily", "AI щодня", .tech, 22_900, 6_880, 1_560, 12, 64, 21),
        ("new-sound", "Новий звук", .music, 41_300, 6_200, 760, 6, 5, 1_020),
        ("football-ua", "Футбол UA", .sport, 188_000, 5_940, 1_020, 7, 9, 1_800),
        ("motion-lab", "Motion Lab", .design, 9_800, 5_310, 690, nil, 82, 9),
        ("news", "Airlance News", .tech, 12_400, 4_880, 620, nil, 18, 300),
        ("indie-games", "Інді-ігри", .games, 27_400, 4_870, 540, 8, 4, 680),
        ("science-plain", "Наука без формул", .science, 35_100, 4_520, 610, 9, 7, 430),
        ("economy-easy", "Економіка просто", .news, 63_800, 4_100, 480, 10, 1, 1_250),
        ("iron-code", "Залізо й код", .tech, 18_600, 3_760, 450, 15, 28, 120),
        ("run-mountains", "Біг і гори", .sport, 12_200, 3_310, 380, 11, 3, 640),
        ("esports-ua", "Кіберспорт UA", .games, 71_000, 2_980, 360, 13, 12, 990),
        ("type-grid", "Шрифти та сітки", .design, 6_400, 2_450, 290, nil, 47, 14),
        ("vinyl-tapes", "Вініл і касети", .music, 8_900, 1_870, 210, 14, 2, 1_500),
    ]

    static func channels() -> [OnAirChannel] {
        rows.map { row in
            OnAirChannel(
                id: row.id,
                name: row.name,
                category: row.category,
                subscribers: row.subscribers,
                score: row.score,
                boosts: row.boosts,
                previousRank: row.previousRank,
                growth: row.growth,
                ageDays: row.ageDays
            )
        }
    }

    static func summaries(now: Date) -> [ChatSummary] {
        let posts = posts(now: now)

        return channels().map { channel in
            let latest = posts
                .filter { post in
                    post.channelID == channel.id
                }
                .max { lhs, rhs in
                    lhs.date < rhs.date
                }
            var chat = ChatSummary(
                id: channel.id,
                name: channel.name,
                kind: .channel,
                message: latest?.text ?? "",
                date: latest?.date ?? now - 86_400
            )
            chat.memberCount = channel.subscribers
            chat.canPost = false
            chat.isPublic = true

            return chat
        }
    }

    static func posts(now: Date) -> [OnAirPost] {
        postRows.enumerated().map { index, row in
            OnAirPost(
                id: "onair-post-\(index)",
                channelID: row.channelID,
                text: row.text,
                date: now - row.hours * 3600,
                views: row.views,
                reactions: row.views / 40,
                boosts: row.boosts,
                comments: row.views / 160
            )
        }
    }

    private static let postRows: [(channelID: String, text: String, hours: Double, views: Int, boosts: Int)] = [
        ("world-5min", "Головне за ніч: перемовини в Женеві тривають, ринки відкрилися зростанням.", 1, 84_000, 140),
        ("ai-daily", "Нова відкрита модель працює на телефоні без інтернету. Перевірили на iPhone — 20 токенів/с.", 2,
         31_000, 210),
        ("swift-weekly", "Swift 6.2: що змінилося в суворій конкурентності і як мігрувати без болю.", 3, 22_000, 96),
        ("space-near", "Сьогодні ввечері МКС пролетить над Україною. Дивіться на захід о 19:42.", 4, 41_000, 120),
        ("kyiv-today", "Метро на лівому березі працюватиме довше у вихідні.", 1.5, 52_000, 38),
        ("motion-lab", "Розбір анімації відкриття картки: пружина, а не крива. Пояснюємо на пальцях.", 5, 7_400,
         160),
        ("football-ua", "Склад збірної на жовтневі матчі: три дебютанти.", 6, 93_000, 70),
        ("design-daily", "Чому порожні стани — найкращі екрани. Вісім прикладів.", 2.5, 12_000, 64),
        ("world-5min", "Що відомо про нову угоду щодо зерна — коротко.", 7, 66_000, 52),
        ("new-sound", "Пʼять альбомів тижня, які варто послухати повністю.", 8, 14_000, 44),
        ("indie-games", "Гра двох студентів з Харкова вийшла в топ Steam за добу.", 3.5, 19_000, 88),
        ("science-plain", "Як працює мРНК — без жодної формули, за три хвилини.", 9, 11_000, 31),
        ("ai-daily", "Шпаргалка: як писати промпти для коду, щоб не переписувати вручну.", 10, 18_000, 72),
        ("type-grid", "Сітка 4 pt чи 8 pt: що обрати для мобільного інтерфейсу.", 4.5, 3_900, 58),
        ("economy-easy", "Курс, інфляція, депозити: що змінилося за тиждень.", 12, 24_000, 18),
        ("iron-code", "Зібрали домашній сервер на ARM за 9 тисяч гривень. Повний список деталей.", 6.5, 8_800, 47),
        ("space-near", "Фото дня: туманність Орла в інфрачервоному діапазоні.", 14, 29_000, 61),
        ("run-mountains", "Маршрут вихідного дня: Говерла з Козьмещика, 11 км.", 16, 6_100, 22),
        ("esports-ua", "Українська команда вийшла у плей-оф мейджору.", 5.5, 38_000, 34),
        ("swift-weekly", "Огляд нових пропозицій Swift Evolution.", 20, 17_000, 40),
        ("vinyl-tapes", "Де шукати старі касети в Києві: пʼять місць.", 22, 2_700, 9),
        ("kyiv-today", "Нові велодоріжки на Подолі відкриють до кінця місяця.", 18, 37_000, 21),
    ]
}
