import UIKit

public struct ListTheme: Equatable, Sendable {
    public var background: UIColor
    public var rowBackground: UIColor
    public var primary: UIColor
    public var secondary: UIColor
    public var separator: UIColor
    public var accent: UIColor
    public var titleFont: UIFont
    public var subtitleFont: UIFont

    public init(
        background: UIColor = .systemBackground,
        rowBackground: UIColor = .systemBackground,
        primary: UIColor = .label,
        secondary: UIColor = .secondaryLabel,
        separator: UIColor = .separator,
        accent: UIColor = .systemBlue,
        titleFont: UIFont = .preferredFont(forTextStyle: .body),
        subtitleFont: UIFont = .preferredFont(forTextStyle: .subheadline)
    ) {
        self.background = background
        self.rowBackground = rowBackground
        self.primary = primary
        self.secondary = secondary
        self.separator = separator
        self.accent = accent
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
    }
}
