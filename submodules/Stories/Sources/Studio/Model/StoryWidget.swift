import Foundation
import UIKit

public struct StoryMentionPeer: Codable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct StoryPlace: Codable, Hashable, Sendable {
    public let title: String
    public let subtitle: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(title: String, subtitle: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct StoryPoll: Codable, Hashable, Sendable {
    public var question: String
    public var options: [String]

    public init(question: String, options: [String]) {
        self.question = question
        self.options = options
    }
}

public enum StoryWidgetStyle: String, CaseIterable, Codable, Sendable {
    case light
    case color
    case dark

    var next: StoryWidgetStyle {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0

        return all[(index + 1) % all.count]
    }
}

public struct StoryWidget: Codable, Hashable, Sendable {
    public enum Kind: Codable, Hashable, Sendable {
        case mention(StoryMentionPeer)
        case location(StoryPlace)
        case link(URL, title: String?)
        case reaction(String)
        case poll(StoryPoll)
        case question(prompt: String, hint: String)
        case addYours(prompt: String, title: String)
    }

    public var kind: Kind
    public var style: StoryWidgetStyle
    public var tint: StoryColor

    public init(kind: Kind, style: StoryWidgetStyle = .light) {
        self.kind = kind
        self.style = style
        tint = StoryColor(kind.defaultTint)
    }
}

public enum StoryWidgetType: String, CaseIterable, Sendable {
    case mention
    case location
    case link
    case reaction
    case poll
    case question
    case addYours

    var symbol: String {
        switch self {
        case .mention:
            "at"
        case .location:
            "mappin.and.ellipse"
        case .link:
            "link"
        case .reaction:
            "heart.fill"
        case .poll:
            "chart.bar.fill"
        case .question:
            "questionmark.bubble.fill"
        case .addYours:
            "plus.square.on.square"
        }
    }

    var label: StoryLabel {
        switch self {
        case .mention:
            .widgetMention
        case .location:
            .widgetLocation
        case .link:
            .widgetLink
        case .reaction:
            .widgetReaction
        case .poll:
            .widgetPoll
        case .question:
            .widgetQuestion
        case .addYours:
            .widgetAddYours
        }
    }
}

public enum StoryInteraction: Sendable {
    case openPeer(String)
    case openPlace(StoryPlace)
    case openLink(URL)
    case react(item: String, emoji: String)
    case vote(item: String, widget: UUID, option: Int)
    case answer(item: String, widget: UUID, text: String)
    case addYours(prompt: String)
    case edit(item: String)
    case delete(item: String)
    case repost(StoryDraft.Media, peer: StoryMentionPeer)
}

extension StoryWidget.Kind {
    var defaultTint: UIColor {
        switch self {
        case .mention:
            UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 1)
        case .location:
            UIColor(red: 0.56, green: 0.33, blue: 0.95, alpha: 1)
        case .link:
            UIColor(red: 0.1, green: 0.62, blue: 0.95, alpha: 1)
        case .reaction:
            UIColor(red: 1, green: 0.27, blue: 0.4, alpha: 1)
        case .poll:
            UIColor(red: 0.18, green: 0.75, blue: 0.45, alpha: 1)
        case .question:
            UIColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
        case .addYours:
            UIColor(red: 0.95, green: 0.3, blue: 0.6, alpha: 1)
        }
    }
}
