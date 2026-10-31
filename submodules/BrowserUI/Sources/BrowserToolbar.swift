import Theme
import UIKit

@MainActor
final class BrowserToolbar: UIView {
    static let height: CGFloat = 49

    let back = BrowserToolbar.button("chevron.backward")
    let forward = BrowserToolbar.button("chevron.forward")
    let share = BrowserToolbar.button("square.and.arrow.up")
    let external = BrowserToolbar.button("safari")
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(separator)
        for button in buttons {
            addSubview(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private var buttons: [UIButton] {
        [back, forward, share, external]
    }

    func apply(_ theme: AppTheme, strings: BrowserStrings) {
        backgroundColor = theme.colors.surface
        separator.backgroundColor = theme.colors.separator
        for button in buttons {
            button.tintColor = theme.colors.accent
        }
        back.accessibilityLabel = strings.back
        forward.accessibilityLabel = strings.forward
        share.accessibilityLabel = strings.share
        external.accessibilityLabel = strings.openExternal
    }

    func update(_ state: BrowserState) {
        back.isEnabled = state.canGoBack
        forward.isEnabled = state.canGoForward
        share.isEnabled = state.url != nil
        external.isEnabled = state.url != nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        separator.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
        let slot = bounds.width / CGFloat(buttons.count)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: slot * CGFloat(index), y: 0, width: slot, height: Self.height)
        }
    }

    private static func button(_ symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)

        return button
    }
}
