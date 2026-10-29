import Theme
import UIKit

enum ProfileAction: CaseIterable {
    case chat
    case mute
    case call
    case more
}

final class ProfileActionButton: UIControl {
    let action: ProfileAction

    private let icon = UIImageView()
    private let label = UILabel()

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.6 : 1
        }
    }

    init(action: ProfileAction) {
        self.action = action
        super.init(frame: .zero)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        icon.contentMode = .center
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        addSubview(icon)
        addSubview(label)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(symbol: String, title: String, theme: AppTheme) {
        backgroundColor = theme.colors.surface
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        icon.image = UIImage(systemName: symbol, withConfiguration: configuration)
        icon.tintColor = theme.colors.accent
        label.text = title
        label.font = theme.fonts.caption
        label.textColor = theme.colors.accent
        accessibilityLabel = title
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        icon.frame = CGRect(x: 0, y: 8, width: bounds.width, height: 24)
        label.frame = CGRect(x: 4, y: 34, width: bounds.width - 8, height: 16)
    }
}

final class ProfileInfoCard: UIView {
    struct Row {
        let value: String
        let key: String
        let isAccent: Bool
    }

    private var values: [UILabel] = []
    private var keys: [UILabel] = []
    private var separators: [UIView] = []
    private var rowHeight: CGFloat = 62

    var contentHeight: CGFloat {
        rowHeight * CGFloat(values.count)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ rows: [Row], theme: AppTheme) {
        if rows.count != values.count {
            rebuild(count: rows.count)
        }
        backgroundColor = theme.colors.surface
        for (index, row) in rows.enumerated() {
            values[index].text = row.value
            values[index].font = theme.fonts.body
            values[index].textColor = row.isAccent ? theme.colors.accent : theme.colors.textPrimary
            keys[index].text = row.key
            keys[index].font = theme.fonts.caption
            keys[index].textColor = theme.colors.textSecondary
        }
        for separator in separators {
            separator.backgroundColor = theme.colors.separator
        }
        rowHeight = ceil(theme.fonts.body.lineHeight + theme.fonts.caption.lineHeight + 24)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width - 32
        for index in values.indices {
            let top = CGFloat(index) * rowHeight
            let valueHeight = ceil(values[index].font.lineHeight)
            values[index].frame = CGRect(x: 16, y: top + 10, width: width, height: valueHeight)
            keys[index].frame = CGRect(
                x: 16,
                y: top + 12 + valueHeight,
                width: width,
                height: ceil(keys[index].font.lineHeight)
            )
        }
        for (index, separator) in separators.enumerated() {
            separator.frame = CGRect(x: 16, y: CGFloat(index + 1) * rowHeight, width: bounds.width - 16, height: 0.5)
        }
    }

    private func rebuild(count: Int) {
        for view in allViews {
            view.removeFromSuperview()
        }
        values = (0..<count).map { _ in
            UILabel()
        }
        keys = (0..<count).map { _ in
            UILabel()
        }
        separators = (0..<max(0, count - 1)).map { _ in
            UIView()
        }
        for view in allViews {
            addSubview(view)
        }
    }

    private var allViews: [UIView] {
        let labels: [UIView] = values + keys

        return labels + separators
    }
}
