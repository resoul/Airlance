import ChatHistory
import ListUI
import UIKit

final class ChatMessagesPopupController: UIViewController {
    private static let headerHeight: CGFloat = 68
    private static let bottomInset: CGFloat = 16
    private static let minimumHeight: CGFloat = 200

    var onSelect: (@MainActor (String) -> Void)?
    var onHold: (@MainActor (String) -> Void)?

    private let titleText: String
    private let presentation: PresentationData
    private let showsNames: Bool
    private let provider: @MainActor () -> [HistoryMessage]
    private let listView = ListView(theme: ListTheme())
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private var messages: [HistoryMessage] = []
    private var items: [any ListItem] = []
    private var builtWidth: CGFloat = 0

    init(
        title: String,
        presentation: PresentationData,
        showsNames: Bool,
        startsAtBottom: Bool,
        messages: @escaping @MainActor () -> [HistoryMessage]
    ) {
        titleText = title
        self.presentation = presentation
        self.showsNames = showsNames
        provider = messages
        self.messages = messages()
        listView.anchorsToBottom = startsAtBottom
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let theme = presentation.theme
        view.backgroundColor = theme.colors.background
        listView.theme = ListTheme(
            background: .clear,
            rowBackground: .clear,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.caption
        )
        listView.contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: Self.bottomInset, right: 0)
        view.addSubview(listView.view)
        titleLabel.text = titleText
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = theme.colors.textPrimary
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        closeButton.tintColor = theme.colors.textPrimary
        closeButton.backgroundColor = theme.colors.textSecondary.withAlphaComponent(0.14)
        closeButton.layer.cornerRadius = 22
        closeButton.accessibilityLabel = presentation.strings.chatCancel
        closeButton.addAction(
            UIAction { [weak self] _ in
                self?.floatingSheet?.close()
            },
            for: .touchUpInside
        )
        view.addSubview(closeButton)
        listView.apply(items: items, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        closeButton.frame = CGRect(x: 16, y: 14, width: 44, height: 44)
        titleLabel.frame = CGRect(x: 68, y: 14, width: width - 136, height: 44)
        let top = Self.headerHeight
        listView.frame = CGRect(x: 0, y: top, width: width, height: view.bounds.height - top)
    }

    func height(for width: CGFloat) -> CGFloat {
        build(width: width)
        let theme = listView.theme
        let rows = items.reduce(CGFloat(0)) { total, item in
            total + item.height(for: width, theme: theme)
        }

        return max(Self.minimumHeight, Self.headerHeight + rows + Self.bottomInset)
    }

    func reload() {
        let next = provider()
        guard next != messages else {
            return
        }

        messages = next
        guard !next.isEmpty else {
            floatingSheet?.close()

            return
        }

        builtWidth = 0
        build(width: view.bounds.width)
        listView.apply(items: items, animated: true)
        floatingSheet?.updateHeight()
    }

    private func build(width: CGFloat) {
        guard width > 0, width != builtWidth else {
            return
        }

        builtWidth = width
        let style = HistoryStyle(theme: presentation.theme)
        let snapshot = HistorySnapshot(
            HistorySnapshot.Request(
                messages: messages,
                contextBefore: nil,
                contextAfter: nil,
                unreadFrom: nil,
                showsNames: showsNames,
                showsAvatars: false,
                width: width,
                scale: traitCollection.displayScale,
                style: style,
                locale: presentation.strings.pack.locale,
                titles: HistorySnapshot.Titles(strings: presentation.strings),
                previous: [:]
            )
        )
        items = snapshot.rows.map { row -> any ListItem in
            switch row {
            case .message(let id, let layout):
                return bubble(id, layout: layout, style: style)
            case .service(let id, let kind, let title):
                return HistoryServiceItem(id: id, kind: kind, title: title, style: style)
            }
        }
        if isViewLoaded {
            listView.apply(items: items, animated: false)
        }
    }

    private func bubble(_ id: String, layout: MessageBubbleLayout, style: HistoryStyle) -> MessageBubbleItem {
        let isBare = layout.videoNote != nil || layout.isBare

        return MessageBubbleItem(
            layout: layout,
            color: isBare ? .clear : style.bubble(outgoing: layout.isOutgoing),
            messageID: id,
            onLongPress: { [weak self] _ in
                self?.onHold?(id)
            },
            onPhotoTap: { [weak self] _, _ in
                self?.onSelect?(id)
            },
            onAction: { [weak self] _ in
                self?.onSelect?(id)
            },
            onBubbleTap: { [weak self] in
                self?.onSelect?(id)
            }
        )
    }
}
