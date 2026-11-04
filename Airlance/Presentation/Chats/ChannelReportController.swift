@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

enum ChannelReportReason: String, CaseIterable, Sendable {
    case dislike
    case childAbuse
    case violence
    case illegalGoods
    case adult
    case personalData
    case scam
    case copyright
    case spam
    case other

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .dislike:
            strings.chatReportReasonDislike
        case .childAbuse:
            strings.chatReportReasonChildAbuse
        case .violence:
            strings.chatReportReasonViolence
        case .illegalGoods:
            strings.chatReportReasonIllegalGoods
        case .adult:
            strings.chatReportReasonAdult
        case .personalData:
            strings.chatReportReasonPersonalData
        case .scam:
            strings.chatReportReasonScam
        case .copyright:
            strings.chatReportReasonCopyright
        case .spam:
            strings.chatReportReasonSpam
        case .other:
            strings.chatReportReasonOther
        }
    }
}

final class ChannelReportController: UIViewController {
    private static let headerHeight: CGFloat = 66
    private static let sectionHeight: CGFloat = 36
    static var height: CGFloat {
        headerHeight + sectionHeight + ReportReasonItem.height * CGFloat(ChannelReportReason.allCases.count) + 20
    }

    var onPick: (@MainActor (ChannelReportReason) -> Void)?

    private let titleText: String
    private let presentation: PresentationData
    private let listView = ListView(theme: ListTheme())
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()

    init(title: String, presentation: PresentationData) {
        titleText = title
        self.presentation = presentation
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let theme = presentation.theme
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
        view.addSubview(listView.view)
        titleLabel.text = titleText
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = theme.colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
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
        listView.apply(items: items(), animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        closeButton.frame = CGRect(x: 16, y: 14, width: 44, height: 44)
        titleLabel.frame = CGRect(x: 68, y: 10, width: width - 136, height: 52)
        let top = Self.headerHeight
        listView.frame = CGRect(x: 0, y: top, width: width, height: view.bounds.height - top)
    }

    private func items() -> [any ListItem] {
        let strings = presentation.strings
        let reasons = ChannelReportReason.allCases
        let rows = reasons.enumerated().map { index, reason in
            ReportReasonItem(
                reason: reason,
                title: reason.title(strings),
                showsSeparator: index < reasons.count - 1
            ) { [weak self] in
                self?.pick(reason)
            }
        }

        return [AttachSectionItem(title: strings.chatReportQuestion)] + rows
    }

    private func pick(_ reason: ChannelReportReason) {
        floatingSheet?.close { [onPick] in
            onPick?(reason)
        }
    }
}

struct ReportReasonItem: ListItem {
    static let height: CGFloat = 52

    let reason: ChannelReportReason
    let title: String
    let showsSeparator: Bool
    let onSelect: @MainActor () -> Void

    var id: String {
        reason.rawValue
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(showsSeparator)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        Self.height
    }

    func makeNode() -> ListItemNode {
        ReportReasonNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? ReportReasonNode)?.update(self, theme: theme)
    }

    func selected() {
        onSelect()
    }
}

final class ReportReasonNode: ListItemNode {
    private let title = ASTextNode()
    private let chevron = ASImageNode()
    private let separator = ASDisplayNode()

    override func didLoad() {
        super.didLoad()
        for node in [title, chevron, separator] {
            node.isLayerBacked = true
            addSubnode(node)
        }
        title.maximumNumberOfLines = 1
        chevron.contentMode = .center
    }

    func update(_ item: ReportReasonItem, theme: ListTheme) {
        backgroundColor = theme.background
        title.attributedText = NSAttributedString(
            string: item.title,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.primary]
        )
        let configuration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: configuration)?
            .withTintColor(theme.secondary, renderingMode: .alwaysOriginal)
        separator.backgroundColor = theme.separator
        separator.isHidden = !item.showsSeparator
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        let width = max(1, bounds.width - 60)
        let size = title.layoutThatFits(ASSizeRange(min: .zero, max: CGSize(width: width, height: 30))).size
        title.frame = CGRect(x: 20, y: (height - size.height) / 2, width: width, height: size.height)
        chevron.frame = CGRect(x: bounds.width - 36, y: 0, width: 20, height: height)
        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: 20, y: height - line, width: bounds.width - 20, height: line)
    }
}
