@preconcurrency import AsyncDisplayKit
import AvatarUI
import Haptics
import ListUI
import UIKit

final class ChatPeekView: UIView {
    struct Item {
        let action: ListSwipeAction
        let isDestructive: Bool
    }

    var onOpen: (@MainActor () -> Void)?

    private static let menuWidth: CGFloat = 240
    private static let headerHeight: CGFloat = 56

    private let blur = UIVisualEffectView(effect: nil)
    private let card = UIView()
    private let header = UIView()
    private let avatar = AvatarNode()
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let menu: MenuListView
    private let history: ChatHistoryController
    private let source: CGRect
    private var target = CGRect.zero

    init(
        chat: ChatSummary,
        history: ChatHistoryController,
        items: [Item],
        presentation: PresentationData,
        source: CGRect,
        host: UIView
    ) {
        self.history = history
        self.source = source
        menu = MenuListView(presentation: presentation, iconsTrailing: true)
        super.init(frame: host.bounds)
        let insets = host.safeAreaInsets
        let menuHeight = MenuListView.rowHeight * CGFloat(items.count)
        let height = min(430, host.bounds.height - insets.top - insets.bottom - menuHeight - 40)
        target = CGRect(x: 16, y: insets.top + 12, width: host.bounds.width - 32, height: height)
        host.addSubview(self)
        blur.frame = bounds
        blur.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss)))
        addSubview(blur)
        buildCard(chat: chat, presentation: presentation)
        buildHistory(chat: chat, presentation: presentation)
        buildMenu(items, height: menuHeight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        Haptics.play(.menu)
        UIView.animate(withDuration: 0.3) {
            self.blur.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0) {
            self.card.frame = self.target
            self.layoutCard()
        }
        UIView.animate(withDuration: 0.45, delay: 0.08, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.menu.alpha = 1
            self.menu.transform = .identity
        }
    }

    private func buildCard(chat: ChatSummary, presentation: PresentationData) {
        let theme = presentation.theme
        let strings = presentation.strings
        card.frame = source
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.backgroundColor = theme.colors.background
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(open)))
        addSubview(card)
        header.backgroundColor = theme.colors.surface
        card.addSubview(header)
        avatar.apply(PeerAvatars.descriptor(id: chat.id, name: chat.name))
        header.addSubnode(avatar)
        nameLabel.text = chat.name
        nameLabel.font = theme.fonts.headline
        nameLabel.textColor = theme.colors.textPrimary
        header.addSubview(nameLabel)
        if chat.kind == .person {
            statusLabel.text = chat.isOnline ? strings.profileOnline : strings.profileLastSeen
        }
        statusLabel.font = theme.fonts.caption
        statusLabel.textColor = chat.isOnline ? theme.colors.accent : theme.colors.textSecondary
        header.addSubview(statusLabel)
        layoutCard()
    }

    private func buildHistory(chat: ChatSummary, presentation: PresentationData) {
        let list = history.listView
        list.frame = CGRect(
            x: 0,
            y: Self.headerHeight,
            width: target.width,
            height: max(0, target.height - Self.headerHeight)
        )
        list.contentInsets = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        card.insertSubview(list.view, belowSubview: header)
        history.load(chat.id, chat: chat)
        history.apply(presentation)
        history.setWidth(target.width)
    }

    private func layoutCard() {
        let width = max(target.width, card.bounds.width)
        header.frame = CGRect(x: 0, y: 0, width: width, height: Self.headerHeight)
        avatar.frame = CGRect(x: 12, y: 10, width: 36, height: 36)
        let nameHeight = ceil(nameLabel.font.lineHeight)
        let statusHeight = statusLabel.text == nil ? 0 : ceil(statusLabel.font.lineHeight)
        let top = (Self.headerHeight - nameHeight - statusHeight) / 2
        nameLabel.frame = CGRect(x: 58, y: top, width: width - 70, height: nameHeight)
        statusLabel.frame = CGRect(x: 58, y: top + nameHeight, width: width - 70, height: statusHeight)
    }

    func track(_ point: CGPoint, ended: Bool) {
        guard isUserInteractionEnabled else {
            return
        }

        menu.track(convert(point, to: menu), ended: ended)
    }

    private func buildMenu(_ items: [Item], height: CGFloat) {
        menu.frame = CGRect(x: target.maxX - Self.menuWidth, y: target.maxY + 10, width: Self.menuWidth, height: height)
        let menuItems = items.map { item in
            MenuItem(
                title: item.action.title,
                symbol: item.action.symbol,
                isDestructive: item.isDestructive,
                action: .run(item.action.handler)
            )
        }
        menu.setItems(menuItems)
        menu.onPerform = { [weak self] item in
            guard case .run(let handler) = item.action else {
                return
            }

            self?.close {
                handler()
            }
        }
        menu.alpha = 0
        menu.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        addSubview(menu)
    }

    @objc
    private func open() {
        Haptics.play(.tap)
        onOpen?()
        UIView.animate(withDuration: 0.25) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    @objc
    private func dismiss() {
        close(nil)
    }

    private func close(_ completion: (@MainActor () -> Void)?) {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.menu.alpha = 0
            self.menu.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.card.frame = self.source
            self.card.alpha = 0
            self.blur.effect = nil
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}
