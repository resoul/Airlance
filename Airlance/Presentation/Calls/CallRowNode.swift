@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

final class CallRowNode: ListItemNode {
    var onDelete: (@MainActor () -> Void)?
    var onInfo: (@MainActor () -> Void)?

    private let avatar = AvatarNode()
    private let outgoingIcon = ASImageNode()
    private let separator = ASDisplayNode()
    private let deleteButton = UIButton(type: .system)
    private let infoButton = UIButton(type: .system)
    private let text = ListRowCanvas()
    private let date = ListRowCanvas()
    private var isEditing = false

    override func didLoad() {
        super.didLoad()
        avatar.isOnScreen = isOnScreen
        outgoingIcon.isLayerBacked = true
        outgoingIcon.contentMode = .center
        separator.isLayerBacked = true
        addSubnode(outgoingIcon)
        addSubnode(avatar)
        addSubnode(separator)
        addSubnode(text)
        addSubnode(date)

        let large = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        deleteButton.setImage(
            UIImage(systemName: "minus.circle.fill", withConfiguration: large)?
                .withTintColor(.systemRed, renderingMode: .alwaysOriginal),
            for: .normal
        )
        infoButton.setImage(UIImage(systemName: "info.circle", withConfiguration: large), for: .normal)
        deleteButton.addAction(
            UIAction { [weak self] _ in
                self?.onDelete?()
            },
            for: .touchUpInside
        )
        infoButton.addAction(
            UIAction { [weak self] _ in
                self?.onInfo?()
            },
            for: .touchUpInside
        )
        view.addSubview(deleteButton)
        view.addSubview(infoButton)
    }

    func update(
        avatar descriptor: AvatarDescriptor,
        storyRing: AvatarStoryRing?,
        isOutgoing: Bool,
        isEditing: Bool,
        showsSeparator: Bool,
        theme: ListTheme
    ) {
        backgroundColor = theme.rowBackground
        avatar.apply(descriptor)
        avatar.setStoryRing(storyRing)
        separator.backgroundColor = theme.separator
        separator.isHidden = !showsSeparator
        infoButton.tintColor = theme.accent
        outgoingIcon.isHidden = !isOutgoing
        if isOutgoing {
            outgoingIcon.image = UIImage(
                systemName: "phone.arrow.up.right",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            )?.withTintColor(theme.secondary, renderingMode: .alwaysOriginal)
        }

        let changed = self.isEditing != isEditing
        self.isEditing = isEditing
        setNeedsLayout()
        if changed {
            view.layoutIfNeeded()
        }
    }

    func apply(_ layout: CallRowLayout) {
        text.frame.size = layout.text.size
        text.apply(layout.text)
        date.frame.size = layout.date.size
        date.apply(layout.date)
        UIView.performWithoutAnimation {
            setNeedsLayout()
            view.layoutIfNeeded()
        }
    }

    override func visibilityChanged() {
        avatar.isOnScreen = isOnScreen
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.prepareForReuse()
        onDelete = nil
        onInfo = nil
        text.apply(nil)
        date.apply(nil)
    }

    override func layout() {
        super.layout()
        let shift = isEditing ? CallRowLayout.editShift : 0
        let midY = bounds.height / 2
        let size = CallRowLayout.avatarSize

        deleteButton.frame = CGRect(x: 4, y: midY - 22, width: 44, height: 44)
        deleteButton.alpha = isEditing ? 1 : 0
        outgoingIcon.frame = CGRect(x: 6 + shift, y: midY - 12, width: 24, height: 24)
        avatar.frame = CGRect(x: CallRowLayout.avatarX + shift, y: midY - size / 2, width: size, height: size)
        infoButton.frame = CGRect(x: bounds.width - 52, y: midY - 22, width: 44, height: 44)
        infoButton.alpha = isEditing ? 0 : 1

        let right = isEditing ? bounds.width - 16 : infoButton.frame.minX - 4
        date.frame.origin = CGPoint(x: right - date.frame.width, y: midY - date.frame.height / 2)

        let textX = avatar.frame.maxX + 12
        text.frame.origin = CGPoint(x: textX, y: midY - text.frame.height / 2)

        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: textX, y: bounds.height - line, width: bounds.width - textX, height: line)
    }
}
