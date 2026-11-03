import UIKit

public struct ThemeChat: Sendable {
    public let outgoingColors: [UIColor]
    public let bubbleRadius: CGFloat
    public let messageFont: UIFont
    public let wallpaper: ThemeWallpaper?
}

public struct ThemeWallpaper: Sendable, Hashable {
    public let kind: ChatWallpaper
    public let colors: [UIColor]
    public let pattern: UIColor
}

extension ChatWallpaper {
    public func resolved(for appearance: ThemeAppearance) -> ThemeWallpaper? {
        ChatPalette.wallpaper(self, appearance: appearance)
    }
}
