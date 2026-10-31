import Haptics
import Theme
import UIKit

final class MessageReceiptsTabs: UIScrollView {
    static let height: CGFloat = 44

    var onSelect: (@MainActor (String?) -> Void)?

    private var chips: [UIButton] = []
    private var keys: [String?] = []
    private let colors: ThemeColors

    init(total: Int, reactions: [(String, Int)], presentation: PresentationData) {
        colors = presentation.theme.colors
        super.init(frame: .zero)
        showsHorizontalScrollIndicator = false
        let all = UIImage(systemName: "person.2.fill")
        chips.append(chip(title: "\(total)", image: all, font: presentation.theme.fonts.caption))
        keys.append(nil)
        for (emoji, count) in reactions {
            chips.append(chip(title: "\(emoji) \(count)", image: nil, font: presentation.theme.fonts.caption))
            keys.append(emoji)
        }
        chips.forEach { chip in
            addSubview(chip)
        }
        select(0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        var x: CGFloat = 12
        for chip in chips {
            let width = ceil(chip.sizeThatFits(CGSize(width: 200, height: 30)).width)
            chip.frame = CGRect(x: x, y: 7, width: width, height: 30)
            x += width + 6
        }
        contentSize = CGSize(width: x + 6, height: bounds.height)
    }

    private func chip(title: String, image: UIImage?, font: UIFont) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = image?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 11))
        configuration.imagePadding = 4
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font

            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.addAction(
            UIAction { [weak self, weak button] _ in
                guard let self, let button, let index = self.chips.firstIndex(of: button) else {
                    return
                }

                Haptics.play(.selection)
                self.select(index)
                self.onSelect?(self.keys[index])
            },
            for: .touchUpInside
        )

        return button
    }

    private func select(_ index: Int) {
        for (offset, chip) in chips.enumerated() {
            let isSelected = offset == index
            chip.configuration?.baseBackgroundColor = isSelected
                ? colors.accent.withAlphaComponent(0.18)
                : colors.textPrimary.withAlphaComponent(0.06)
            chip.configuration?.baseForegroundColor = isSelected ? colors.accent : colors.textPrimary
        }
    }
}
