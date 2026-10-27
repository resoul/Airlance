import UIKit

public enum ThemeAppearance: Sendable {
    case light
    case dark

    public init(_ style: UIUserInterfaceStyle) {
        switch style {
        case .dark:
            self = .dark

        default:
            self = .light
        }
    }

    public var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light:
            .light

        case .dark:
            .dark
        }
    }
}
