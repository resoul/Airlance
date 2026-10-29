@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

enum HistoryServiceKind: Sendable, Hashable {
    case date
    case unread
    case action(target: String?)
}

struct HistoryServiceItem: ListItem {
    let id: String
    let kind: HistoryServiceKind
    let title: String
    let style: HistoryStyle
    var onTap: (@MainActor () -> Void)?

    var version: Int {
        var hasher = Hasher()
        hasher.combine(kind)
        hasher.combine(title)
        hasher.combine(style)

        return hasher.finalize()
    }

    var reuseIdentifier: String {
        "service"
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        let line = ceil(style.metaFont.lineHeight)
        switch kind {
        case .date:
            return line + 6 + 20
        case .unread:
            return line + 10 + 16
        case .action:
            let text = HistoryServiceNode.text(title, style: style, centered: true)
            let bounds = text.boundingRect(
                with: CGSize(width: HistoryServiceNode.actionWidth(in: width), height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            return ceil(bounds.height) + 8 + 12
        }
    }

    func tapped(node: ListItemNode, at point: CGPoint) {
        onTap?()
    }

    func makeNode() -> ListItemNode {
        HistoryServiceNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? HistoryServiceNode)?.update(self)
    }
}

final class HistoryServiceNode: ListItemNode {
    private let background = ASDisplayNode()
    private let label = ASTextNode()
    private var kind = HistoryServiceKind.date

    override func didLoad() {
        super.didLoad()
        background.isLayerBacked = true
        label.isLayerBacked = true
        label.maximumNumberOfLines = 1
        addSubnode(background)
        addSubnode(label)
    }

    func update(_ item: HistoryServiceItem) {
        kind = item.kind
        background.backgroundColor = item.style.serviceBackground
        if case .action = item.kind {
            label.maximumNumberOfLines = 0
            label.attributedText = Self.text(item.title, style: item.style, centered: true)
        } else {
            label.maximumNumberOfLines = 1
            label.attributedText = Self.text(item.title, style: item.style, centered: false)
        }
        setNeedsLayout()
    }

    static func actionWidth(in width: CGFloat) -> CGFloat {
        min(width - 80, 300)
    }

    static func text(_ title: String, style: HistoryStyle, centered: Bool) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [.font: style.metaFont, .foregroundColor: style.serviceText]
        if centered {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            attributes[.paragraphStyle] = paragraph
        }

        return NSAttributedString(string: title, attributes: attributes)
    }

    override func layout() {
        super.layout()
        let maxWidth = kind == .date || kind == .unread ? bounds.width - 48 : Self.actionWidth(in: bounds.width)
        let range = ASSizeRange(min: .zero, max: CGSize(width: maxWidth, height: bounds.height))
        let size = label.layoutThatFits(range).size
        let labelSize = CGSize(width: ceil(size.width), height: ceil(size.height))
        switch kind {
        case .date:
            let pill = CGSize(width: labelSize.width + 20, height: labelSize.height + 6)
            background.frame = CGRect(
                x: (bounds.width - pill.width) / 2,
                y: (bounds.height - pill.height) / 2,
                width: pill.width,
                height: pill.height
            )
            background.cornerRadius = pill.height / 2
        case .unread:
            background.frame = CGRect(x: 0, y: 8, width: bounds.width, height: bounds.height - 16)
            background.cornerRadius = 0
        case .action:
            let pill = CGSize(width: labelSize.width + 20, height: labelSize.height + 8)
            background.frame = CGRect(
                x: (bounds.width - pill.width) / 2,
                y: (bounds.height - pill.height) / 2,
                width: pill.width,
                height: pill.height
            )
            background.cornerRadius = min(pill.height / 2, 14)
        }
        label.frame = CGRect(
            x: (bounds.width - labelSize.width) / 2,
            y: background.frame.midY - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }
}
