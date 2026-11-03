import Theme
import UIKit

struct HistoryStyle: Sendable, Hashable {
    let textFont: UIFont
    let metaFont: UIFont
    let nameFont: UIFont
    let quoteFont: UIFont
    let incomingBubble: UIColor
    let outgoingBubble: UIColor
    let outgoingColors: [UIColor]
    let bubbleRadius: CGFloat
    let hasWallpaper: Bool
    let incomingText: UIColor
    let outgoingText: UIColor
    let incomingMeta: UIColor
    let outgoingMeta: UIColor
    let name: UIColor
    let failed: UIColor
    let success: UIColor
    let mediaPlaceholder: UIColor
    let serviceBackground: UIColor
    let serviceText: UIColor
    let isDark: Bool

    init(theme: AppTheme) {
        let colors = theme.colors
        textFont = theme.chat.messageFont
        metaFont = theme.fonts.caption
        nameFont = Self.bold(theme.fonts.subheadline)
        quoteFont = theme.fonts.subheadline
        incomingBubble = colors.surface
        outgoingBubble = theme.chat.outgoingColors.first ?? colors.accent
        outgoingColors = theme.chat.outgoingColors
        bubbleRadius = theme.chat.bubbleRadius
        hasWallpaper = theme.chat.wallpaper != nil
        incomingText = colors.textPrimary
        outgoingText = colors.onAccent
        incomingMeta = colors.textSecondary
        outgoingMeta = colors.onAccent.withAlphaComponent(0.72)
        name = colors.accent
        failed = colors.destructive
        success = .systemGreen
        mediaPlaceholder = colors.separator
        serviceBackground = hasWallpaper ? UIColor.black.withAlphaComponent(0.24) : colors.surface
        serviceText = hasWallpaper ? .white : colors.textSecondary
        isDark = theme.appearance == .dark
    }

    func bubble(outgoing: Bool) -> UIColor {
        outgoing ? outgoingBubble : incomingBubble
    }

    func gradient(outgoing: Bool) -> [UIColor]? {
        outgoing && outgoingColors.count > 1 ? outgoingColors : nil
    }

    func text(outgoing: Bool) -> UIColor {
        outgoing ? outgoingText : incomingText
    }

    func meta(outgoing: Bool) -> UIColor {
        outgoing ? outgoingMeta : incomingMeta
    }

    func tint(outgoing: Bool) -> UIColor {
        outgoing ? outgoingText : name
    }

    static func bold(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return font
        }

        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
