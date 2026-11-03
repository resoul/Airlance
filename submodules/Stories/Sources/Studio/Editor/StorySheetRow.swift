import UIKit

final class StorySheetRow: UIControl {
    static let height: CGFloat = 48

    let toggle = UISwitch()
    private let icon = UIImageView()
    private let title = UILabel()
    private let detail = UILabel()
    private let check = UIImageView()

    init(symbol: String, title text: String, hasToggle: Bool = false) {
        super.init(frame: .zero)
        let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        icon.image = UIImage(systemName: symbol, withConfiguration: configuration)
        icon.tintColor = .white
        icon.contentMode = .center
        title.text = text
        title.font = .systemFont(ofSize: 16, weight: .medium)
        title.textColor = .white
        detail.font = .systemFont(ofSize: 15)
        detail.textColor = UIColor(white: 1, alpha: 0.5)
        detail.textAlignment = .right
        detail.lineBreakMode = .byTruncatingTail
        check.image = UIImage(systemName: "checkmark", withConfiguration: configuration)
        check.tintColor = .white
        check.contentMode = .center
        check.isHidden = true
        toggle.isHidden = !hasToggle
        toggle.onTintColor = .systemGreen
        for view in [icon, title, detail, check, toggle] {
            view.isUserInteractionEnabled = view === toggle
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isChecked: Bool {
        get {
            !check.isHidden
        }
        set {
            check.isHidden = !newValue
        }
    }

    func setTitle(_ text: String) {
        title.text = text
        setNeedsLayout()
    }

    func setDetail(_ text: String?) {
        detail.text = text
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        icon.frame = CGRect(x: 0, y: 0, width: 28, height: bounds.height)
        let titleWidth = min(ceil(title.intrinsicContentSize.width), bounds.width * 0.6)
        title.frame = CGRect(x: 40, y: 0, width: titleWidth, height: bounds.height)
        let trailing: CGFloat = toggle.isHidden ? 28 : 60
        check.frame = CGRect(x: bounds.width - 24, y: 0, width: 24, height: bounds.height)
        toggle.center = CGPoint(x: bounds.width - toggle.bounds.width / 2, y: bounds.midY)
        let detailX = title.frame.maxX + 12
        detail.frame = CGRect(x: detailX, y: 0, width: max(bounds.width - trailing - detailX, 0), height: bounds.height)
    }
}
