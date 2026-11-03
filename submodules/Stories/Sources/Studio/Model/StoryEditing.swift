import CoreGraphics
import Foundation

public enum StoryTextStyle: String, CaseIterable, Codable, Sendable {
    case shadow
    case filled
    case semi
    case outline
}

public enum StoryFont: String, CaseIterable, Codable, Sendable {
    case bold
    case rounded
    case serif
    case mono
    case hand
}

public enum StoryBrush: String, CaseIterable, Codable, Sendable {
    case pen
    case marker
    case neon
    case arrow
    case eraser
}

public enum StoryFilter: String, CaseIterable, Codable, Sendable {
    case original
    case vivid
    case warm
    case cool
    case fade
    case mono
    case noir
    case chrome
}

public struct StoryAdjustments: Codable, Hashable, Sendable {
    public var filter = StoryFilter.original
    public var brightness: Double = 0
    public var contrast: Double = 0
    public var saturation: Double = 0
    public var warmth: Double = 0
    public var vignette: Double = 0

    public init() {
    }

    public var isIdentity: Bool {
        self == StoryAdjustments()
    }
}

public struct StoryMediaTransform: Codable, Hashable, Sendable {
    public var scale: CGFloat = 1
    public var offset = CGPoint.zero
    public var rotation: CGFloat = 0

    public init() {
    }

    public var isIdentity: Bool {
        self == StoryMediaTransform()
    }

    public func affine(in size: CGSize) -> CGAffineTransform {
        CGAffineTransform(translationX: offset.x * size.width, y: offset.y * size.height)
            .rotated(by: rotation)
            .scaledBy(x: scale, y: scale)
    }
}

public struct StoryTrim: Codable, Hashable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval {
        max(end - start, 0)
    }
}
