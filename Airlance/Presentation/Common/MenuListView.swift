import Haptics
import UIKit

struct MenuItem {
    enum Action {
        case run(@MainActor () -> Void)
        case submenu([MenuItem])
    }

    let title: String
    let symbol: String?
    let isDestructive: Bool
    let action: Action
}

final class MenuListView: UIView {
    static let rowHeight: CGFloat = 44

    var onPerform: (@MainActor (MenuItem) -> Void)?

    private(set) var items: [MenuItem] = []
    private let presentation: PresentationData
    private let iconsTrailing: Bool
    private var rows: [MenuRow] = []
    private var highlighted: Int?

    var contentHeight: CGFloat {
        Self.rowHeight * CGFloat(items.count)
    }

    init(presentation: PresentationData, iconsTrailing: Bool = false) {
        self.presentation = presentation
        self.iconsTrailing = iconsTrailing
        super.init(frame: .zero)
        backgroundColor = presentation.theme.colors.surface
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        clipsToBounds = true
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        press.minimumPressDuration = 0
        addGestureRecognizer(press)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setItems(_ items: [MenuItem]) {
        self.items = items
        highlighted = nil
        rows.forEach { row in
            row.removeFromSuperview()
        }
        rows = items.map { item in
            MenuRow(item: item, presentation: presentation, iconTrailing: iconsTrailing)
        }
        for (index, row) in rows.enumerated() {
            row.showsSeparator = index < rows.count - 1
            addSubview(row)
        }
        setNeedsLayout()
    }

    func track(_ point: CGPoint, ended: Bool) {
        let index = bounds.contains(point) ? Int(point.y / Self.rowHeight) : nil
        let target = index.flatMap { index in
            rows.indices.contains(index) ? index : nil
        }
        if target != highlighted {
            highlight(target)
            if target != nil, !ended {
                Haptics.play(.selection)
            }
        }
        guard ended else {
            return
        }

        highlight(nil)
        if let target {
            onPerform?(items[target])
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, row) in rows.enumerated() {
            row.frame = CGRect(x: 0, y: CGFloat(index) * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
        }
    }

    private func highlight(_ index: Int?) {
        highlighted = index
        for (offset, row) in rows.enumerated() {
            row.isHighlighted = offset == index
        }
    }

    @objc
    private func pressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            track(gesture.location(in: self), ended: false)
        case .ended:
            track(gesture.location(in: self), ended: true)
        default:
            highlight(nil)
        }
    }
}

final class MenuRow: UIView {
    var isHighlighted = false {
        didSet {
            highlight.alpha = isHighlighted ? 1 : 0
        }
    }

    var showsSeparator = true {
        didSet {
            separator.isHidden = !showsSeparator
        }
    }

    private let title = UILabel()
    private let icon = UIImageView()
    private let highlight = UIView()
    private let separator = UIView()
    private let iconTrailing: Bool

    init(item: MenuItem, presentation: PresentationData, iconTrailing: Bool) {
        self.iconTrailing = iconTrailing
        super.init(frame: .zero)
        let colors = presentation.theme.colors
        let color = item.isDestructive ? colors.destructive : colors.textPrimary
        highlight.backgroundColor = colors.textPrimary.withAlphaComponent(0.08)
        highlight.alpha = 0
        addSubview(highlight)
        title.text = item.title
        title.font = presentation.theme.fonts.body
        title.textColor = color
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.8
        addSubview(title)
        icon.image = item.symbol.flatMap { symbol in
            UIImage(systemName: symbol)
        }
        icon.tintColor = color
        icon.contentMode = .center
        addSubview(icon)
        separator.backgroundColor = colors.separator
        addSubview(separator)
        isAccessibilityElement = true
        accessibilityLabel = item.title
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlight.frame = bounds
        separator.frame = CGRect(x: 0, y: bounds.height - 0.5, width: bounds.width, height: 0.5)
        let hasIcon = icon.image != nil
        if iconTrailing {
            icon.frame = CGRect(x: bounds.width - 40, y: 0, width: 26, height: bounds.height)
            let trailing: CGFloat = hasIcon ? 48 : 16
            title.frame = CGRect(x: 16, y: 0, width: bounds.width - 16 - trailing, height: bounds.height)
        } else {
            icon.frame = CGRect(x: 14, y: 0, width: 26, height: bounds.height)
            let titleX: CGFloat = hasIcon ? 52 : 18
            title.frame = CGRect(x: titleX, y: 0, width: bounds.width - titleX - 16, height: bounds.height)
        }
    }
}
