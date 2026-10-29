import ChatHistory
import Foundation

struct HistorySnapshot: Sendable {
    enum Row: Sendable {
        case message(id: String, layout: MessageBubbleLayout)
        case service(id: String, kind: HistoryServiceKind, title: String)
    }

    struct Request: Sendable {
        let messages: [HistoryMessage]
        let contextBefore: HistoryMessage?
        let contextAfter: HistoryMessage?
        let unreadFrom: String?
        let showsNames: Bool
        let showsAvatars: Bool
        let width: CGFloat
        let scale: CGFloat
        let style: HistoryStyle
        let locale: Locale
        let titles: Titles
        let previous: [String: MessageBubbleLayout]
    }

    struct Titles: Sendable {
        let today: String
        let yesterday: String
        let unread: String
        let you: String
        let photo: String
        let video: String
        let voice: String
        let location: String
        let forwarded: String
        let edited: String
        let created: @Sendable (String) -> String
        let joined: @Sendable (String) -> String
        let renamed: @Sendable (String) -> String
        let pinned: @Sendable (String) -> String
    }

    let rows: [Row]
    let layouts: [String: MessageBubbleLayout]
    let series: [AvatarSeries]

    init(_ request: Request) {
        let calendar = Calendar.current
        let formatter = Formatters(locale: request.locale)
        let now = Date()
        var rows: [Row] = []
        var layouts: [String: MessageBubbleLayout] = [:]
        var series = AvatarSeriesBuilder()
        let entries = Self.entries(request, calendar: calendar)
        for entry in entries {
            switch entry {
            case .date(let day):
                let title = formatter.day(day, now: now, calendar: calendar, titles: request.titles)
                rows.append(.service(id: entry.id, kind: .date, title: title))
            case .unread:
                rows.append(.service(id: entry.id, kind: .unread, title: request.titles.unread))
            case .message(let message, _) where message.content.isService:
                rows.append(Self.serviceRow(message, titles: request.titles))
            case .message(let message, let grouping):
                let time = formatter.time.string(from: message.date)
                let input = MessageBubbleInput(
                    message: message,
                    grouping: grouping,
                    showsName: request.showsNames && !message.isOutgoing && !grouping.joinedTop,
                    reservesAvatar: request.showsAvatars && !message.isOutgoing,
                    timeText: message.isEdited ? "\(request.titles.edited) \(time)" : time,
                    reply: Self.quote(message.reply, titles: request.titles),
                    forwardTitle: message.forward == nil ? nil : request.titles.forwarded
                )
                let layout = Self.layout(input, request: request)
                layouts[message.id] = layout
                if input.reservesAvatar {
                    series.add(message, grouping: grouping, row: rows.count, layout: layout)
                }
                rows.append(.message(id: message.id, layout: layout))
            }
        }
        self.rows = rows
        self.layouts = layouts
        self.series = series.result
    }

    private static func quote(_ reply: MessageReply?, titles: Titles) -> ReplyQuote? {
        reply.map { reply in
            ReplyQuote(
                messageID: reply.messageID,
                title: reply.isOutgoing ? titles.you : reply.authorName,
                text: quoteText(reply, titles: titles),
                photo: reply.photo
            )
        }
    }

    private static func entries(_ request: Request, calendar: Calendar) -> [HistoryEntry] {
        HistoryBuilder(calendar: calendar).entries(
            for: request.messages,
            unreadFrom: request.unreadFrom,
            before: request.contextBefore,
            after: request.contextAfter
        )
    }

    private static func serviceRow(_ message: HistoryMessage, titles: Titles) -> Row {
        guard case .service(let service) = message.content else {
            return .service(id: message.id, kind: .action(target: nil), title: "")
        }

        return .service(
            id: message.id,
            kind: .action(target: service.targetID),
            title: serviceTitle(service, titles: titles)
        )
    }

    private static func serviceTitle(_ service: MessageService, titles: Titles) -> String {
        switch service {
        case .created(let title):
            return titles.created(title)
        case .joined(let name):
            return titles.joined(name)
        case .renamed(let title):
            return titles.renamed(title)
        case .pinned(let reply):
            let text = quoteText(reply, titles: titles).replacingOccurrences(of: "\n", with: " ")

            return titles.pinned(text.count > 40 ? String(text.prefix(40)) + "…" : text)
        }
    }

    private static func quoteText(_ reply: MessageReply, titles: Titles) -> String {
        if reply.isVoice {
            return titles.voice
        }

        if reply.isLocation {
            return titles.location
        }

        if let name = reply.fileName, reply.text.isEmpty {
            return name
        }

        guard reply.text.isEmpty else {
            return reply.text
        }

        return reply.photo?.video == nil ? titles.photo : titles.video
    }

    private static func layout(_ input: MessageBubbleInput, request: Request) -> MessageBubbleLayout {
        let key = MessageBubbleLayout.key(input, style: request.style)
        if let previous = request.previous[input.message.id], previous.key == key, previous.width == request.width {
            return previous
        }

        return MessageBubbleLayout(input, width: request.width, scale: request.scale, style: request.style)
    }
}

extension HistorySnapshot.Titles {
    init(strings: AppStrings) {
        self.init(
            today: strings.chatToday,
            yesterday: strings.chatYesterday,
            unread: strings.chatUnread,
            you: strings.chatYou,
            photo: strings.chatPhoto,
            video: strings.chatVideo,
            voice: strings.chatVoiceMessage,
            location: strings.chatLocation,
            forwarded: strings.chatForwardedFrom,
            edited: strings.chatEdited,
            created: { title in
                strings.chatServiceCreated(title)
            },
            joined: { name in
                strings.chatServiceJoined(name)
            },
            renamed: { title in
                strings.chatServiceRenamed(title)
            },
            pinned: { text in
                strings.chatServicePinned(text)
            }
        )
    }
}

private struct Formatters {
    let time: DateFormatter
    private let thisYear: DateFormatter
    private let older: DateFormatter

    init(locale: Locale) {
        time = Self.formatter(locale: locale, template: "jmm")
        thisYear = Self.formatter(locale: locale, template: "dMMMM")
        older = Self.formatter(locale: locale, template: "dMMMMyyyy")
    }

    func day(_ day: Date, now: Date, calendar: Calendar, titles: HistorySnapshot.Titles) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return titles.today
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)
        if let yesterday, calendar.isDate(day, inSameDayAs: yesterday) {
            return titles.yesterday
        }

        let sameYear = calendar.isDate(day, equalTo: now, toGranularity: .year)

        return (sameYear ? thisYear : older).string(from: day)
    }

    private static func formatter(locale: Locale, template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)

        return formatter
    }
}
