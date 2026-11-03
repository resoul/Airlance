import Theme
import UIKit

final class StorageRow: UIControl {
    static let height: CGFloat = 54

    let category: StorageCategory

    private let check = UIImageView()
    private let icon = UIImageView()
    private let name = UILabel()
    private let percent = UILabel()
    private let size = UILabel()
    private let separator = UIView()

    var isOn = true {
        didSet {
            updateCheck()
        }
    }

    var valueCenter: CGPoint {
        CGPoint(x: size.frame.maxX - 20, y: size.frame.midY)
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? UIColor.label.withAlphaComponent(0.05) : nil
        }
    }

    init(category: StorageCategory) {
        self.category = category
        super.init(frame: .zero)
        let configuration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        icon.image = UIImage(systemName: category.symbol, withConfiguration: configuration)
        icon.tintColor = .white
        icon.contentMode = .center
        icon.backgroundColor = category.color
        icon.layer.cornerRadius = 8
        icon.layer.cornerCurve = .continuous
        check.contentMode = .center
        size.textAlignment = .right
        for view in [check, icon, name, percent, size, separator] {
            view.isUserInteractionEnabled = false
            addSubview(view)
        }
        updateCheck()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme, title: String) {
        name.text = title
        name.font = theme.fonts.body
        name.textColor = theme.colors.textPrimary
        percent.font = theme.fonts.caption
        percent.textColor = theme.colors.textSecondary
        size.font = theme.fonts.body
        size.textColor = theme.colors.textSecondary
        separator.backgroundColor = theme.colors.separator
        check.tintColor = theme.colors.accent
    }

    func show(bytes: Int64, share: Double, isFirst: Bool) {
        size.text = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        percent.text = share > 0 ? String(format: "%.1f%%", share * 100) : ""
        isEnabled = bytes > 0
        alpha = bytes > 0 ? 1 : 0.45
        setNeedsLayout()
    }

    func pulse() {
        UIView.animate(withDuration: 0.12) {
            self.size.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.25) {
                self.size.transform = .identity
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = bounds.height
        check.frame = CGRect(x: 12, y: 0, width: 28, height: height)
        icon.frame = CGRect(x: 46, y: (height - 30) / 2, width: 30, height: 30)
        let sizeWidth: CGFloat = 96
        size.frame = CGRect(x: bounds.width - 16 - sizeWidth, y: 0, width: sizeWidth, height: height)
        let x = icon.frame.maxX + 12
        let percentWidth = ceil(percent.sizeThatFits(bounds.size).width)
        name.frame = CGRect(x: x, y: 0, width: max(0, size.frame.minX - x - percentWidth - 12), height: height)
        let nameWidth = min(name.frame.width, ceil(name.sizeThatFits(bounds.size).width))
        percent.frame = CGRect(x: x + nameWidth + 6, y: 1, width: percentWidth, height: height)
        separator.frame = CGRect(x: x, y: height - 0.5, width: bounds.width - x, height: 0.5)
    }

    private func updateCheck() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let name = isOn ? "checkmark.circle.fill" : "circle"
        check.image = UIImage(systemName: name, withConfiguration: configuration)
        check.alpha = isOn ? 1 : 0.5
    }
}
