import Haptics
import Theme
import UIKit

final class ThemeCardsView: UIView {
    enum Layout {
        case strip(width: CGFloat)
        case grid(columns: Int)
    }

    var onSelect: (@MainActor (Int) -> Void)?

    private let layout: Layout
    private let aspect: CGFloat
    private let scroll = UIScrollView()
    private var cards: [ThemeCardView] = []

    init(layout: Layout, aspect: CGFloat) {
        self.layout = layout
        self.aspect = aspect
        super.init(frame: .zero)
        scroll.showsHorizontalScrollIndicator = false
        var isStrip = false
        if case .strip = layout {
            isStrip = true
        }
        scroll.alwaysBounceHorizontal = isStrip
        scroll.isScrollEnabled = isStrip
        addSubview(scroll)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ models: [ThemeCardModel], selected: Int?, theme: AppTheme) {
        while cards.count < models.count {
            let card = ThemeCardView()
            let index = cards.count
            card.addAction(UIAction { [weak self] _ in
                Haptics.play(.selection)
                self?.onSelect?(index)
            }, for: .touchUpInside)
            scroll.addSubview(card)
            cards.append(card)
        }
        for (index, card) in cards.enumerated() {
            card.isHidden = index >= models.count
            if index < models.count {
                card.apply(models[index], selected: index == selected, theme: theme)
            }
        }
        setNeedsLayout()
    }

    func height(for width: CGFloat, count: Int, captions: Bool) -> CGFloat {
        let extra = captions ? ThemeCardView.captionHeight : 0
        switch layout {
        case .strip(let cardWidth):
            return cardWidth * aspect + extra
        case .grid(let columns):
            let side = (width - CGFloat(columns - 1) * 10) / CGFloat(columns)
            let rows = (count + columns - 1) / columns

            return CGFloat(rows) * (side * aspect + extra) + CGFloat(max(rows - 1, 0)) * 10
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scroll.frame = bounds
        let visible = cards.filter { card in
            !card.isHidden
        }
        switch layout {
        case .strip(let width):
            var x: CGFloat = 0
            for card in visible {
                card.frame = CGRect(x: x, y: 0, width: width, height: bounds.height)
                x += width + 10
            }
            scroll.contentSize = CGSize(width: max(x - 10, 0), height: bounds.height)
        case .grid(let columns):
            let side = (bounds.width - CGFloat(columns - 1) * 10) / CGFloat(columns)
            let rows = max((visible.count + columns - 1) / columns, 1)
            let height = (bounds.height - CGFloat(rows - 1) * 10) / CGFloat(rows)
            for (index, card) in visible.enumerated() {
                card.frame = CGRect(
                    x: CGFloat(index % columns) * (side + 10),
                    y: CGFloat(index / columns) * (height + 10),
                    width: side,
                    height: height
                )
            }
            scroll.contentSize = bounds.size
        }
    }
}

final class AccentRowView: UIView {
    static let height: CGFloat = 64

    var onSelect: (@MainActor (ThemeAccent) -> Void)?

    private let scroll = UIScrollView()
    private var circles: [ThemeAccent: UIButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        scroll.showsHorizontalScrollIndicator = false
        addSubview(scroll)
        for accent in ThemeAccent.allCases {
            let button = UIButton(type: .custom)
            button.layer.cornerRadius = 22
            button.addAction(UIAction { [weak self] _ in
                Haptics.play(.selection)
                self?.onSelect?(accent)
            }, for: .touchUpInside)
            scroll.addSubview(button)
            circles[accent] = button
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(selected: ThemeAccent, theme: AppTheme, title: (ThemeAccent) -> String) {
        for (accent, button) in circles {
            button.backgroundColor = accent.color(for: theme.appearance)
            button.layer.borderWidth = accent == selected ? 3 : 0
            button.layer.borderColor = theme.colors.background.cgColor
            button.layer.shadowColor = accent.color(for: theme.appearance).cgColor
            button.layer.shadowOpacity = accent == selected ? 1 : 0
            button.layer.shadowRadius = 0
            button.layer.shadowOffset = .zero
            button.accessibilityLabel = title(accent)
            button.accessibilityTraits = accent == selected ? [.button, .selected] : .button
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scroll.frame = bounds
        var x: CGFloat = 6
        for accent in ThemeAccent.allCases {
            guard let button = circles[accent] else {
                continue
            }

            button.frame = CGRect(x: x, y: (bounds.height - 44) / 2, width: 44, height: 44)
            button.layer.shadowPath = UIBezierPath(ovalIn: button.bounds.insetBy(dx: -3, dy: -3)).cgPath
            x += 56
        }
        scroll.contentSize = CGSize(width: x, height: bounds.height)
    }
}
