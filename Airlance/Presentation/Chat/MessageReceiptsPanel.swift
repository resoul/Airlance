import AvatarUI
import ChatHistory
import Haptics
import UIKit

struct MessageMenuReceipts {
    struct Row {
        let person: MessageCommenter
        let detail: String?
        let reaction: String?
    }

    let summary: String
    let symbol: String
    let avatars: [MessageCommenter]
    let rows: [Row]
}

final class MessageReceiptsPanel: UIView {
    static let summaryHeight: CGFloat = 44
    static let rowHeight: CGFloat = 50

    var onToggle: (@MainActor (Bool) -> Void)?

    private(set) var isExpanded = false
    private let receipts: MessageMenuReceipts
    private let summary = UIControl()
    private let icon = UIImageView()
    private let title = UILabel()
    private let avatars = UIView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let list = UIScrollView()
    private let back = UIButton(type: .system)
    private var rows: [MessageReceiptsRow] = []
    private var tabs: MessageReceiptsTabs?
    private var filter: String?

    private var listTop: CGFloat {
        Self.summaryHeight + (tabs == nil ? 0 : MessageReceiptsTabs.height)
    }

    init(receipts: MessageMenuReceipts, presentation: PresentationData, backTitle: String) {
        self.receipts = receipts
        super.init(frame: .zero)
        let colors = presentation.theme.colors
        backgroundColor = colors.surface
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        clipsToBounds = true
        icon.image = UIImage(systemName: receipts.symbol)
        icon.tintColor = colors.textPrimary
        icon.contentMode = .center
        title.text = receipts.summary
        title.font = presentation.theme.fonts.body
        title.textColor = colors.textPrimary
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.75
        chevron.tintColor = colors.textSecondary
        chevron.contentMode = .center
        chevron.isHidden = !isExpandable
        for view in [icon, title, avatars, chevron] {
            view.isUserInteractionEnabled = false
            summary.addSubview(view)
        }
        summary.addTarget(self, action: #selector(summaryTapped), for: .touchUpInside)
        summary.isEnabled = isExpandable
        addSubview(summary)
        placeAvatars(colors.surface)
        setupList(presentation, backTitle: backTitle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isExpandable: Bool {
        !receipts.rows.isEmpty
    }

    func expandedHeight(limit: CGFloat) -> CGFloat {
        let content = listTop + Self.rowHeight * CGFloat(rows.count)

        return max(Self.summaryHeight, min(content, limit))
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        summary.alpha = expanded ? 0 : 1
        list.alpha = expanded ? 1 : 0
        list.contentOffset = .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        summary.frame = CGRect(x: 0, y: 0, width: width, height: Self.summaryHeight)
        icon.frame = CGRect(x: 14, y: 0, width: 26, height: Self.summaryHeight)
        chevron.frame = CGRect(x: width - 30, y: 0, width: 18, height: Self.summaryHeight)
        let avatarsRight = isExpandable ? chevron.frame.minX - 4 : width - 14
        avatars.frame.origin = CGPoint(
            x: avatarsRight - avatars.bounds.width,
            y: (Self.summaryHeight - avatars.bounds.height) / 2
        )
        title.frame = CGRect(x: 52, y: 0, width: max(0, avatars.frame.minX - 60), height: Self.summaryHeight)
        list.frame = bounds
        back.frame = CGRect(x: 0, y: 0, width: width, height: Self.summaryHeight)
        tabs?.frame = CGRect(x: 0, y: Self.summaryHeight, width: width, height: MessageReceiptsTabs.height)
        var y = listTop
        for (index, row) in rows.enumerated() {
            let isShown = filter == nil || receipts.rows[index].reaction == filter
            row.isHidden = !isShown
            if isShown {
                row.frame = CGRect(x: 0, y: y, width: width, height: Self.rowHeight)
                y += Self.rowHeight
            }
        }
        list.contentSize = CGSize(width: width, height: y)
    }

    private func placeAvatars(_ border: UIColor) {
        let side: CGFloat = 24
        let step: CGFloat = 16
        let people = Array(receipts.avatars.prefix(3))
        for (index, person) in people.enumerated().reversed() {
            let image = UIImageView(image: MessageReceiptsRow.avatar(person, side: side))
            image.frame = CGRect(x: CGFloat(index) * step, y: 0, width: side, height: side)
            image.layer.cornerRadius = side / 2
            image.layer.borderWidth = 1.5
            image.layer.borderColor = border.cgColor
            image.clipsToBounds = true
            avatars.addSubview(image)
        }
        let width = people.isEmpty ? 0 : side + CGFloat(people.count - 1) * step
        avatars.bounds = CGRect(x: 0, y: 0, width: width, height: side)
    }

    private func setupList(_ presentation: PresentationData, backTitle: String) {
        list.alpha = 0
        list.alwaysBounceVertical = false
        list.showsVerticalScrollIndicator = false
        let font = presentation.theme.fonts.body
        var configuration = UIButton.Configuration.plain()
        configuration.title = backTitle
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.imagePadding = 10
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        configuration.baseForegroundColor = presentation.theme.colors.textPrimary
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font

            return attributes
        }
        back.configuration = configuration
        back.contentHorizontalAlignment = .leading
        back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        list.addSubview(back)
        rows = receipts.rows.map { row in
            MessageReceiptsRow(row: row, presentation: presentation)
        }
        rows.forEach { row in
            list.addSubview(row)
        }
        addTabs(presentation)
        addSubview(list)
    }

    private func addTabs(_ presentation: PresentationData) {
        var emojis: [String] = []
        for row in receipts.rows {
            if let emoji = row.reaction, !emojis.contains(emoji) {
                emojis.append(emoji)
            }
        }
        let hasPlainReaders = receipts.rows.contains { row in
            row.reaction == nil
        }
        guard !emojis.isEmpty, emojis.count > 1 || hasPlainReaders else {
            return
        }

        let counts = emojis.map { emoji in
            (emoji, receipts.rows.filter { row in
                row.reaction == emoji
            }.count)
        }
        let tabs = MessageReceiptsTabs(total: receipts.rows.count, reactions: counts, presentation: presentation)
        tabs.onSelect = { [weak self] emoji in
            self?.filter = emoji
            UIView.animate(withDuration: 0.2) {
                self?.layoutSubviews()
            }
        }
        list.addSubview(tabs)
        self.tabs = tabs
    }

    @objc
    private func summaryTapped() {
        Haptics.play(.tap)
        onToggle?(true)
    }

    @objc
    private func backTapped() {
        Haptics.play(.tap)
        onToggle?(false)
    }
}

final class MessageReceiptsRow: UIView {
    private static let avatarSide: CGFloat = 32

    private let avatar = UIImageView()
    private let name = UILabel()
    private let detail = UILabel()
    private let reaction = UILabel()
    private let separator = UIView()

    init(row: MessageMenuReceipts.Row, presentation: PresentationData) {
        super.init(frame: .zero)
        let colors = presentation.theme.colors
        avatar.image = Self.avatar(row.person, side: Self.avatarSide)
        avatar.layer.cornerRadius = Self.avatarSide / 2
        avatar.clipsToBounds = true
        name.text = row.person.name
        name.font = presentation.theme.fonts.body
        name.textColor = colors.textPrimary
        detail.text = row.detail
        detail.font = presentation.theme.fonts.caption
        detail.textColor = colors.textSecondary
        reaction.text = row.reaction
        reaction.font = .systemFont(ofSize: 20)
        reaction.textAlignment = .center
        separator.backgroundColor = colors.separator
        for view in [avatar, name, detail, reaction, separator] {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    static func avatar(_ person: MessageCommenter, side: CGFloat) -> UIImage {
        AvatarDescriptor(id: person.id, initials: AvatarDescriptor.initials(from: person.name))
            .placeholderImage(side: side, scale: UIScreen.main.scale)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = Self.avatarSide
        separator.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
        avatar.frame = CGRect(x: 14, y: (bounds.height - side) / 2, width: side, height: side)
        reaction.frame = CGRect(x: bounds.width - 44, y: 0, width: 32, height: bounds.height)
        let x = avatar.frame.maxX + 12
        let width = max(0, reaction.frame.minX - x - 4)
        guard detail.text != nil else {
            name.frame = CGRect(x: x, y: 0, width: width, height: bounds.height)

            return
        }

        name.frame = CGRect(x: x, y: 7, width: width, height: 20)
        detail.frame = CGRect(x: x, y: 27, width: width, height: 16)
    }
}
