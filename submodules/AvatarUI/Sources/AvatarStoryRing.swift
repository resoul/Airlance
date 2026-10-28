import UIKit

public struct AvatarStoryRing: Sendable, Equatable {
    public var totalCount: Int
    public var unseenCount: Int
    public var unseenColors: [UIColor]
    public var seenColors: [UIColor]
    public var lineWidth: CGFloat
    public var seenLineWidth: CGFloat

    public init(
        totalCount: Int,
        unseenCount: Int,
        unseenColors: [UIColor],
        seenColors: [UIColor],
        lineWidth: CGFloat = 2.33,
        seenLineWidth: CGFloat = 1.33
    ) {
        self.totalCount = totalCount
        self.unseenCount = unseenCount
        self.unseenColors = unseenColors
        self.seenColors = seenColors
        self.lineWidth = lineWidth
        self.seenLineWidth = seenLineWidth
    }

    public var hasUnseen: Bool {
        unseenCount > 0
    }

    var contentInset: CGFloat {
        lineWidth * 2
    }
}
