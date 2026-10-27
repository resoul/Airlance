import UIKit

public struct SystemTraits: Equatable, Sendable {
    public let appearance: ThemeAppearance
    public let contentSize: UIContentSizeCategory

    public init(appearance: ThemeAppearance, contentSize: UIContentSizeCategory) {
        self.appearance = appearance
        self.contentSize = contentSize
    }

    public init(_ traits: UITraitCollection) {
        appearance = ThemeAppearance(traits.userInterfaceStyle)
        contentSize = traits.preferredContentSizeCategory == .unspecified ? .large : traits.preferredContentSizeCategory
    }
}
