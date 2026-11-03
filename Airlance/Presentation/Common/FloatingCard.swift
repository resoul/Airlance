import Theme
import UIKit

final class FloatingCard: UIView {
    let content = UIView()
    var radius: CGFloat = 18 {
        didSet {
            content.layer.cornerRadius = radius
            setNeedsLayout()
        }
    }
    private var rows: [(view: UIView, height: CGFloat)] = []

    var height: CGFloat {
        rows.reduce(0) { total, row in
            total + row.height
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        content.clipsToBounds = true
        content.layer.cornerRadius = radius
        content.layer.cornerCurve = .continuous
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme) {
        FloatingStyle.style(content, theme: theme, hasShadow: false)
        FloatingStyle.style(self, theme: theme, hasShadow: true)
        backgroundColor = .clear
        layer.borderWidth = 0
    }

    func setRows(_ rows: [(view: UIView, height: CGFloat)]) {
        self.rows = rows
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        var y: CGFloat = 0
        for row in rows {
            row.view.frame = CGRect(x: 0, y: y, width: bounds.width, height: row.height)
            y += row.height
        }
    }
}

@MainActor
enum FloatingStyle {
    static let gap: CGFloat = 6

    static func style(_ view: UIView, theme: AppTheme, hasShadow: Bool = true) {
        view.backgroundColor = theme.colors.surface
        view.layer.borderColor = theme.colors.separator.cgColor
        view.layer.borderWidth = 1 / max(view.traitCollection.displayScale, 1)
        view.layer.cornerCurve = .continuous
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = hasShadow ? 0.12 : 0
        view.layer.shadowRadius = 12
        view.layer.shadowOffset = CGSize(width: 0, height: 3)
    }
}
