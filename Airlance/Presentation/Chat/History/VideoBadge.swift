@preconcurrency import AsyncDisplayKit
import UIKit

enum VideoBadge {
    private static let playSize: CGFloat = 44

    static func make(duration: TimeInterval, frame: CGRect, style: HistoryStyle) -> ASDisplayNode {
        let container = ASDisplayNode()
        container.isLayerBacked = true
        container.frame = frame
        container.addSubnode(durationNode(duration, style: style))
        if frame.width >= playSize * 1.5, frame.height >= playSize * 1.5 {
            container.addSubnode(playNode(in: CGRect(origin: .zero, size: frame.size)))
        }

        return container
    }

    static func text(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))

        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func durationNode(_ duration: TimeInterval, style: HistoryStyle) -> ASDisplayNode {
        let label = ASTextNode()
        label.isLayerBacked = true
        label.maximumNumberOfLines = 1
        label.attributedText = NSAttributedString(
            string: text(duration),
            attributes: [.font: style.metaFont, .foregroundColor: UIColor.white]
        )
        let size = MessageBubbleLayout.measure(label, width: 80)
        let background = ASDisplayNode()
        background.isLayerBacked = true
        background.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        background.frame = CGRect(x: 6, y: 6, width: size.width + 12, height: size.height + 4)
        background.cornerRadius = background.frame.height / 2
        label.frame = CGRect(origin: CGPoint(x: 6, y: 2), size: size)
        background.addSubnode(label)

        return background
    }

    private static func playNode(in bounds: CGRect) -> ASDisplayNode {
        let circle = ASDisplayNode()
        circle.isLayerBacked = true
        circle.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        circle.frame = CGRect(
            x: bounds.midX - playSize / 2,
            y: bounds.midY - playSize / 2,
            width: playSize,
            height: playSize
        )
        circle.cornerRadius = playSize / 2
        let icon = ASImageNode()
        icon.isLayerBacked = true
        icon.contentMode = .center
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        icon.image = UIImage(systemName: "play.fill", withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        icon.frame = CGRect(x: 2, y: 0, width: playSize, height: playSize)
        circle.addSubnode(icon)

        return circle
    }
}
