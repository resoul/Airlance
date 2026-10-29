import Theme
import UIKit

final class ProfileNavigationBar: UIView {
    let backButton = UIButton(type: .system)

    private let background = UIView()
    private let separator = UIView()
    private let titleLabel = UILabel()
    private var accent = UIColor.systemBlue
    private var isFilled = false
    private var isOnPhoto = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        background.alpha = 0
        background.addSubview(separator)
        titleLabel.alpha = 0
        titleLabel.textAlignment = .center
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        backButton.setImage(UIImage(systemName: "chevron.backward", withConfiguration: configuration), for: .normal)
        addSubview(background)
        addSubview(titleLabel)
        addSubview(backButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(title: String, back: String, theme: AppTheme) {
        titleLabel.text = title
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = theme.colors.textPrimary
        background.backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.separator
        backButton.accessibilityLabel = back
        accent = theme.colors.accent
        updateTint()
    }

    func setState(filled: Bool, onPhoto: Bool) {
        if filled != isFilled {
            isFilled = filled
            UIView.animate(withDuration: 0.2) {
                self.background.alpha = filled ? 1 : 0
                self.titleLabel.alpha = filled ? 1 : 0
            }
        }
        if onPhoto != isOnPhoto {
            isOnPhoto = onPhoto
            updateTint()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let top = safeAreaInsets.top
        background.frame = bounds
        separator.frame = CGRect(x: 0, y: bounds.height - 0.5, width: bounds.width, height: 0.5)
        backButton.frame = CGRect(x: 4, y: top, width: 44, height: 44)
        titleLabel.frame = CGRect(x: 60, y: top, width: bounds.width - 120, height: 44)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if let view, view.isDescendant(of: backButton) {
            return view
        }

        return isFilled ? view : nil
    }

    private func updateTint() {
        backButton.tintColor = isOnPhoto ? .white : accent
    }
}
