import CoreGraphics
import Foundation

public struct Toast {
    public enum Edge: Sendable {
        case top
        case bottom
    }

    public enum Style: Sendable {
        case info
        case success
        case error
    }

    public let text: String
    public let symbol: String?
    public let style: Style
    public let edge: Edge
    public let inset: CGFloat
    public let duration: TimeInterval
    public let action: (@MainActor () -> Void)?

    public init(
        _ text: String,
        symbol: String? = nil,
        style: Style = .info,
        edge: Edge = .top,
        inset: CGFloat = 0,
        duration: TimeInterval? = nil,
        action: (@MainActor () -> Void)? = nil
    ) {
        self.text = text
        self.symbol = symbol
        self.style = style
        self.edge = edge
        self.inset = inset
        self.duration = duration ?? Self.readingTime(for: text)
        self.action = action
    }

    var key: String {
        "\(symbol ?? "")|\(text)"
    }

    private static func readingTime(for text: String) -> TimeInterval {
        min(5, max(2, 1.4 + Double(text.count) * 0.04))
    }
}
