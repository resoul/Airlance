import Haptics
import UIKit

public final class StoryPalette: UIView {
    public static let colors: [UIColor] = [
        .white,
        .black,
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemBlue,
        .systemPurple,
    ]
    public static let height: CGFloat = 36

    public var onSelect: (@MainActor (UIColor) -> Void)?

    public private(set) var selected = StoryPalette.colors[0]
    private var swatches: [UIButton] = []

    override public init(frame: CGRect) {
        super.init(frame: frame)
        swatches = Self.colors.map { color in
            let swatch = UIButton(type: .custom)
            swatch.backgroundColor = color
            swatch.layer.borderColor = UIColor.white.cgColor
            swatch.layer.borderWidth = 2
            swatch.addAction(UIAction { [weak self] _ in
                self?.select(color)
            }, for: .touchUpInside)
            addSubview(swatch)

            return swatch
        }
        select(selected, notify: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func select(_ color: UIColor, notify: Bool = true) {
        selected = color
        for (swatch, candidate) in zip(swatches, Self.colors) {
            let isSelected = candidate == color
            UIView.animate(withDuration: 0.15) {
                swatch.transform = isSelected ? CGAffineTransform(scaleX: 1.25, y: 1.25) : .identity
            }
            swatch.layer.borderWidth = isSelected ? 3 : 2
        }
        guard notify else {
            return
        }

        Haptics.play(.selection)
        onSelect?(color)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 26
        let step = bounds.width / CGFloat(max(swatches.count, 1))
        for (index, swatch) in swatches.enumerated() {
            let transform = swatch.transform
            swatch.transform = .identity
            swatch.frame = CGRect(
                x: step * (CGFloat(index) + 0.5) - side / 2,
                y: (bounds.height - side) / 2,
                width: side,
                height: side
            )
            swatch.layer.cornerRadius = side / 2
            swatch.transform = transform
        }
    }
}
