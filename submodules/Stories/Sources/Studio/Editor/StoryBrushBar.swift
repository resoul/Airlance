import Haptics
import UIKit

final class StoryBrushBar: UIView {
    static let height: CGFloat = 44

    var onSelect: (@MainActor (StoryBrush) -> Void)?

    private var buttons: [UIButton] = []
    private(set) var selected = StoryBrush.pen

    init(strings: StoryStudioStrings) {
        super.init(frame: .zero)
        buttons = StoryBrush.allCases.map { brush in
            let button = UIButton(type: .system)
            let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            button.setImage(UIImage(systemName: Self.symbol(brush), withConfiguration: configuration), for: .normal)
            button.tintColor = .white
            button.accessibilityLabel = strings.label(Self.label(brush))
            button.addAction(UIAction { [weak self] _ in
                self?.select(brush)
            }, for: .touchUpInside)
            addSubview(button)

            return button
        }
        select(.pen, notify: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func select(_ brush: StoryBrush, notify: Bool = true) {
        selected = brush
        for (index, button) in buttons.enumerated() {
            let isSelected = StoryBrush.allCases[index] == brush
            button.backgroundColor = isSelected ? UIColor.white : UIColor.black.withAlphaComponent(0.35)
            button.tintColor = isSelected ? .black : .white
        }
        if notify {
            Haptics.play(.selection)
            onSelect?(brush)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = Self.height
        let spacing = (bounds.width - side * CGFloat(buttons.count)) / CGFloat(max(buttons.count - 1, 1))
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * (side + spacing), y: 0, width: side, height: side)
            button.layer.cornerRadius = side / 2
        }
    }

    private static func symbol(_ brush: StoryBrush) -> String {
        switch brush {
        case .pen:
            "pencil.tip"
        case .marker:
            "highlighter"
        case .neon:
            "wand.and.rays"
        case .arrow:
            "arrow.up.right"
        case .eraser:
            "eraser"
        }
    }

    private static func label(_ brush: StoryBrush) -> StoryLabel {
        switch brush {
        case .pen:
            .penBrush
        case .marker:
            .markerBrush
        case .neon:
            .neonBrush
        case .arrow:
            .arrowBrush
        case .eraser:
            .eraser
        }
    }
}
