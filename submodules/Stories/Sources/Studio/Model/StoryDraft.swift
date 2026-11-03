import Foundation
import Subtitles
import UIKit

public enum StoryAudience: String, CaseIterable, Codable, Sendable {
    case everyone
    case contacts
    case closeFriends
    case selected
}

public struct StoryColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(_ color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = Double(red)
        self.green = Double(green)
        self.blue = Double(blue)
        self.alpha = Double(alpha)
    }

    public var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

public struct StoryText: Codable, Hashable, Sendable {
    public var text: String
    public var color: StoryColor
    public var style: StoryTextStyle
    public var font: StoryFont

    public init(text: String, color: StoryColor, style: StoryTextStyle = .shadow, font: StoryFont = .bold) {
        self.text = text
        self.color = color
        self.style = style
        self.font = font
    }
}

public struct StoryStroke: Codable, Hashable, Sendable {
    public var points: [CGPoint]
    public var color: StoryColor
    public var width: CGFloat
    public var brush: StoryBrush

    public init(points: [CGPoint], color: StoryColor, width: CGFloat, brush: StoryBrush = .pen) {
        self.points = points
        self.color = color
        self.width = width
        self.brush = brush
    }
}

public struct StorySticker: Codable, Hashable, Sendable {
    public enum Source: Codable, Hashable, Sendable {
        case emoji(String)
        case image(URL)
    }

    public var source: Source
    public var width: CGFloat

    public init(source: Source, width: CGFloat = 0.32) {
        self.source = source
        self.width = width
    }
}

public struct StoryEntity: Codable, Hashable, Identifiable, Sendable {
    public enum Content: Codable, Hashable, Sendable {
        case text(StoryText)
        case drawing(StoryStroke)
        case sticker(StorySticker)
        case widget(StoryWidget)
    }

    public let id: UUID
    public var content: Content
    public var center: CGPoint
    public var scale: CGFloat
    public var rotation: CGFloat

    public init(
        content: Content,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5),
        scale: CGFloat = 1,
        rotation: CGFloat = 0
    ) {
        id = UUID()
        self.content = content
        self.center = center
        self.scale = scale
        self.rotation = rotation
    }

    public var isDrawing: Bool {
        if case .drawing = content {
            return true
        }

        return false
    }

    public var widget: StoryWidget? {
        if case .widget(let widget) = content {
            return widget
        }

        return nil
    }
}

public struct StoryDraft: Codable, Sendable {
    public enum Media: Codable, Hashable, Sendable {
        case photo(URL)
        case video(URL)

        public var url: URL {
            switch self {
            case .photo(let url), .video(let url):
                url
            }
        }
    }

    public let id: UUID
    public var media: Media
    public var entities: [StoryEntity] = []
    public var subtitles: Subtitles?
    public var audience = StoryAudience.everyone
    public var aspect = CGSize(width: 9, height: 19.5)
    public var adjustments = StoryAdjustments()
    public var mediaTransform = StoryMediaTransform()
    public var trim: StoryTrim?
    public var coverTime: TimeInterval = 0
    public var sound = StorySound()
    public var settings = StoryPublishSettings()
    public var createdAt = Date()

    public init(media: Media) {
        id = UUID()
        self.media = media
    }
}

public struct StoryResult: Sendable {
    public let media: StoryDraft.Media
    public let draft: StoryDraft
    public let cover: URL?

    public init(media: StoryDraft.Media, draft: StoryDraft, cover: URL? = nil) {
        self.media = media
        self.draft = draft
        self.cover = cover
    }
}
