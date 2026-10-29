import Haptics
import UIKit

final class ForwardPickerView: UIView {
    private static let rowHeight: CGFloat = 56
    private static let headerHeight: CGFloat = 52

    var onSelect: (@MainActor (ChatSummary) -> Void)?

    private let dim = UIView()
    private let card = UIView()
    private let titleLabel = UILabel()
    private let list = UIScrollView()
    private let chats: [ChatSummary]
    private var cardHeight: CGFloat = 0

    init(chats: [ChatSummary], title: String, presentation: PresentationData, host: UIView) {
        self.chats = chats
        super.init(frame: host.bounds)
        host.addSubview(self)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dim.alpha = 0
        dim.frame = bounds
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss)))
        addSubview(dim)
        buildCard(title: title, presentation: presentation, safeBottom: host.safeAreaInsets.bottom)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        Haptics.play(.popup)
        card.transform = CGAffineTransform(translationX: 0, y: cardHeight)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0) {
            self.dim.alpha = 1
            self.card.transform = .identity
        }
    }

    private func buildCard(title: String, presentation: PresentationData, safeBottom: CGFloat) {
        let theme = presentation.theme
        let contentHeight = Self.rowHeight * CGFloat(chats.count)
        cardHeight = min(bounds.height * 0.7, Self.headerHeight + contentHeight + safeBottom + 8)
        card.frame = CGRect(x: 0, y: bounds.height - cardHeight, width: bounds.width, height: cardHeight + 40)
        card.backgroundColor = theme.colors.background
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        addSubview(card)
        titleLabel.text = title
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = theme.colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.frame = CGRect(x: 16, y: 0, width: bounds.width - 32, height: Self.headerHeight)
        card.addSubview(titleLabel)
        list.frame = CGRect(
            x: 0,
            y: Self.headerHeight,
            width: bounds.width,
            height: cardHeight - Self.headerHeight
        )
        list.contentSize = CGSize(width: bounds.width, height: contentHeight + safeBottom + 8)
        list.alwaysBounceVertical = true
        card.addSubview(list)
        for (index, chat) in chats.enumerated() {
            let row = row(for: chat, presentation: presentation)
            row.frame = CGRect(x: 0, y: CGFloat(index) * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
            list.addSubview(row)
        }
    }

    private func row(for chat: ChatSummary, presentation: PresentationData) -> UIView {
        let theme = presentation.theme
        let row = UIButton(type: .custom)
        row.accessibilityLabel = chat.name
        let avatar = AvatarHostView(PeerAvatars.descriptor(id: chat.id, name: chat.name))
        avatar.isUserInteractionEnabled = false
        avatar.frame = CGRect(x: 16, y: 8, width: 40, height: 40)
        row.addSubview(avatar)
        let name = UILabel()
        name.text = chat.name
        name.font = theme.fonts.body
        name.textColor = theme.colors.textPrimary
        name.frame = CGRect(x: 68, y: 0, width: bounds.width - 84, height: Self.rowHeight)
        row.addSubview(name)
        let separator = UIView()
        separator.backgroundColor = theme.colors.separator
        separator.frame = CGRect(x: 68, y: Self.rowHeight - 0.5, width: bounds.width - 68, height: 0.5)
        row.addSubview(separator)
        row.addAction(
            UIAction { [weak self] _ in
                self?.select(chat)
            },
            for: .touchUpInside
        )

        return row
    }

    private func select(_ chat: ChatSummary) {
        Haptics.play(.tap)
        close { [weak self] in
            self?.onSelect?(chat)
        }
    }

    @objc
    private func dismiss() {
        close(nil)
    }

    private func close(_ completion: (@MainActor () -> Void)?) {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.dim.alpha = 0
            self.card.transform = CGAffineTransform(translationX: 0, y: self.cardHeight)
        } completion: { _ in
            completion?()
            self.removeFromSuperview()
        }
    }
}
