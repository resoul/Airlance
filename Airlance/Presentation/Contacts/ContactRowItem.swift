@preconcurrency import AsyncDisplayKit
import AvatarUI
import DeviceContacts
import ListUI
import UIKit

struct ContactRowItem: AsyncListItem {
    let contact: DeviceContact
    let thumbnails: DeviceContactThumbnails
    let revision: Int
    let showsSeparator: Bool
    var isSelected: Bool?
    var onSelect: (@MainActor () -> Void)?

    var id: String {
        contact.id
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(contact.displayName)
        hasher.combine(contact.phoneNumbers.first)
        hasher.combine(contact.hasImage)
        hasher.combine(revision)
        hasher.combine(showsSeparator)
        hasher.combine(isSelected)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        ContactRowLayout.height(theme: theme)
    }

    func makeNode() -> ListItemNode {
        ContactRowNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? ContactRowNode)?.update(
            avatar: avatar(),
            showsSeparator: showsSeparator,
            isSelected: isSelected,
            theme: theme
        )
    }

    nonisolated func prepareLayout(width: CGFloat, theme: ListTheme, displayScale: CGFloat) -> any ListPreparedLayout {
        ContactRowLayout(
            title: contact.displayName,
            subtitle: contact.phoneNumbers.first ?? "",
            width: width - ContactRowLayout.textX - ContactRowLayout.inset - (isSelected == nil ? 0 : 40),
            height: ContactRowLayout.height(theme: theme),
            theme: theme
        )
    }

    func apply(_ layout: any ListPreparedLayout, to node: ListItemNode) {
        guard let layout = layout as? ContactRowLayout else {
            return
        }

        (node as? ContactRowNode)?.apply(layout)
    }

    func selected() {
        onSelect?()
    }

    private func avatar() -> AvatarDescriptor {
        let letters = [contact.givenName.first, contact.familyName.first].compactMap { letter in
            letter.map(String.init)
        }
        let initials = letters.joined()
        let id = contact.id
        let thumbnails = thumbnails
        let image = contact.hasImage ? AvatarImage(key: "contact:\(id):\(revision)") {
            await thumbnails.data(for: id)
        } : nil

        return AvatarDescriptor(
            id: id,
            initials: initials.isEmpty ? AvatarDescriptor.initials(from: contact.displayName) : initials,
            image: image
        )
    }
}

final class ContactRowLayout: ListPreparedLayout, @unchecked Sendable {
    static let inset: CGFloat = 16
    static let avatarSize: CGFloat = 44
    static let textX: CGFloat = inset + avatarSize + 12

    let title: ASTextNode
    let subtitle: ASTextNode?

    init(title: String, subtitle: String, width: CGFloat, height: CGFloat, theme: ListTheme) {
        let width = max(1, width)
        let title = Self.text(title, font: theme.titleFont, color: theme.primary, width: width)
        let subtitle = subtitle.isEmpty
            ? nil
            : Self.text(subtitle, font: theme.subtitleFont, color: theme.secondary, width: width)
        let textHeight = title.frame.height + (subtitle.map { node in
            2 + node.frame.height
        } ?? 0)
        let top = ((height - textHeight) / 2).rounded()

        title.frame.origin = CGPoint(x: Self.textX, y: top)
        subtitle?.frame.origin = CGPoint(x: Self.textX, y: top + title.frame.height + 2)
        self.title = title
        self.subtitle = subtitle
    }

    static func height(theme: ListTheme) -> CGFloat {
        max(60, (theme.titleFont.lineHeight + 2 + theme.subtitleFont.lineHeight + 20).rounded(.up))
    }

    private static func text(_ string: String, font: UIFont, color: UIColor, width: CGFloat) -> ASTextNode {
        let node = ASTextNode()
        node.isLayerBacked = true
        node.maximumNumberOfLines = 1
        node.truncationMode = .byTruncatingTail
        node.attributedText = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let range = ASSizeRange(min: .zero, max: CGSize(width: width, height: .greatestFiniteMagnitude))
        node.frame = CGRect(origin: .zero, size: node.layoutThatFits(range).size)

        return node
    }
}
