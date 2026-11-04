import Theme
import UIKit

final class AttachTabBar: UIView {
    struct Item {
        let tag: Int
        let title: String
        let symbol: String
    }

    static let height: CGFloat = 64
    private static let minimumItemWidth: CGFloat = 74
    private static let inset: CGFloat = 4

    var onSelect: (@MainActor (Int) -> Void)?

    private let scroll = UIScrollView()
    private let pill = UIView()
    private let colors: ThemeColors
    private var buttons: [UIButton] = []
    private var selectedTag: Int?

    init(items: [Item], theme: AppTheme) {
        colors = theme.colors
        super.init(frame: .zero)
        FloatingStyle.style(self, theme: theme)
        layer.cornerRadius = Self.height / 2
        scroll.showsHorizontalScrollIndicator = false
        scroll.layer.cornerRadius = Self.height / 2
        scroll.layer.cornerCurve = .continuous
        addSubview(scroll)
        pill.backgroundColor = theme.colors.textSecondary.withAlphaComponent(0.16)
        pill.layer.cornerCurve = .continuous
        scroll.addSubview(pill)
        let font = theme.fonts.caption.withSize(11)
        buttons = items.map { item in
            makeButton(item, font: font)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func select(_ tag: Int, animated: Bool) {
        selectedTag = tag
        for button in buttons {
            button.tintColor = button.tag == tag ? colors.accent : colors.textPrimary
        }
        guard let button = buttons.first(where: { button in
            button.tag == tag
        }), bounds.width > 0 else {
            setNeedsLayout()

            return
        }

        scroll.scrollRectToVisible(button.frame.insetBy(dx: -40, dy: 0), animated: animated)
        guard animated else {
            placePill(on: button)

            return
        }

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0) {
            self.placePill(on: button)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Self.height / 2).cgPath
        scroll.frame = bounds
        let inset = Self.inset
        let fitting = (bounds.width - inset * 2) / CGFloat(max(buttons.count, 1))
        let width = max(Self.minimumItemWidth, fitting)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: inset + CGFloat(index) * width, y: 0, width: width, height: bounds.height)
        }
        scroll.contentSize = CGSize(width: inset * 2 + CGFloat(buttons.count) * width, height: bounds.height)
        if let selectedTag {
            select(selectedTag, animated: false)
        }
    }

    private func placePill(on button: UIButton) {
        pill.frame = button.frame.insetBy(dx: 1, dy: Self.inset)
        pill.layer.cornerRadius = pill.bounds.height / 2
    }

    private func makeButton(_ item: Item, font: UIFont) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: item.symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20)
        )
        configuration.title = item.title
        configuration.imagePlacement = .top
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font

            return attributes
        }
        button.configuration = configuration
        button.tag = item.tag
        button.addAction(
            UIAction { [weak self] _ in
                self?.onSelect?(item.tag)
            },
            for: .touchUpInside
        )
        scroll.addSubview(button)

        return button
    }
}
