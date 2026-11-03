import Haptics
import UIKit

final class StoryStickerPicker: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    static let emoji = [
        "😂", "😍", "🥰", "😎", "🤩", "🥳", "😭", "😱", "🤯", "😴", "🤔", "🫠", "😇", "🤗", "🙃", "😏",
        "👍", "👏", "🙌", "🙏", "💪", "✌️", "🤞", "👀", "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
        "🔥", "✨", "⭐️", "🌟", "💯", "🎉", "🎊", "🎈", "🎁", "🏆", "🥇", "🚀", "⚡️", "💥", "🌈", "☀️",
        "🌙", "❄️", "🌊", "🌸", "🌻", "🍀", "🍕", "🍔", "🍟", "🍣", "🍩", "🍰", "☕️", "🍷", "🍺", "🥂",
        "⚽️", "🏀", "🎾", "🎮", "🎧", "🎸", "🎬", "📸", "✈️", "🏖", "🏔", "🏙", "🐶", "🐱", "🦊", "🐼",
        "🦄", "🐝", "🦋", "🌵", "🇺🇦", "🤌", "🙈", "😜", "🤪", "😤", "🥺", "😬", "🤝", "🫶", "💀", "👻",
    ]

    var onPick: (@MainActor (String, Bool) -> Void)?
    var onWidget: (@MainActor (StoryWidgetType) -> Void)?
    var onClose: (@MainActor () -> Void)?

    private let dim = UIView()
    private let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
    private let layout = UICollectionViewFlowLayout()
    private lazy var grid = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let chips = UIScrollView()
    private let hint = UILabel()
    private let strings: StoryStudioStrings
    private var chipButtons: [StoryWidgetType: UIButton] = [:]
    private var isReaction = false

    init(frame: CGRect, strings: StoryStudioStrings) {
        self.strings = strings
        super.init(frame: frame)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        addSubview(dim)
        panel.layer.cornerRadius = 22
        panel.layer.cornerCurve = .continuous
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        addSubview(panel)
        grid.backgroundColor = .clear
        grid.dataSource = self
        grid.delegate = self
        grid.register(StoryEmojiCell.self, forCellWithReuseIdentifier: StoryEmojiCell.identifier)
        panel.contentView.addSubview(grid)
        setUpChips()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dim.frame = bounds
        let height = bounds.height * 0.56
        panel.frame = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
        chips.frame = CGRect(x: 0, y: 14, width: panel.bounds.width, height: 36)
        layoutChips()
        hint.frame = CGRect(x: 16, y: chips.frame.maxY + 6, width: panel.bounds.width - 32, height: isReaction ? 20 : 0)
        let gridTop = hint.frame.maxY + 10
        grid.frame = panel.bounds.inset(by: UIEdgeInsets(top: gridTop, left: 12, bottom: 0, right: 12))
        grid.contentInset.bottom = safeAreaInsets.bottom + 12
        let side = floor((grid.bounds.width - 7 * 6) / 8)
        layout.itemSize = CGSize(width: side, height: side)
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
    }

    func show() {
        dim.alpha = 0
        panel.transform = CGAffineTransform(translationX: 0, y: bounds.height / 2)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.dim.alpha = 1
            self.panel.transform = .identity
        }
    }

    func hide() {
        UIView.animate(withDuration: 0.22) {
            self.dim.alpha = 0
            self.panel.transform = CGAffineTransform(translationX: 0, y: self.panel.bounds.height)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Self.emoji.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoryEmojiCell.identifier, for: indexPath)
        (cell as? StoryEmojiCell)?.label.text = Self.emoji[indexPath.item]

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onPick?(Self.emoji[indexPath.item], isReaction)
    }

    private func setUpChips() {
        chips.showsHorizontalScrollIndicator = false
        chips.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        panel.contentView.addSubview(chips)
        hint.font = .systemFont(ofSize: 13, weight: .medium)
        hint.textColor = UIColor(white: 1, alpha: 0.6)
        hint.textAlignment = .center
        hint.text = strings.label(.widgetReactionHint)
        hint.alpha = 0
        panel.contentView.addSubview(hint)
        for type in StoryWidgetType.allCases {
            let button = UIButton(type: .system)
            let configuration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
            button.setImage(UIImage(systemName: type.symbol, withConfiguration: configuration), for: .normal)
            button.setTitle(" " + strings.label(type.label), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.layer.cornerRadius = 18
            button.layer.cornerCurve = .continuous
            button.addAction(UIAction { [weak self] _ in
                self?.chipTapped(type)
            }, for: .touchUpInside)
            chips.addSubview(button)
            chipButtons[type] = button
        }
        styleChips()
    }

    private func layoutChips() {
        var x: CGFloat = 0
        for type in StoryWidgetType.allCases {
            guard let button = chipButtons[type] else {
                continue
            }

            let width = ceil(button.intrinsicContentSize.width) + 24
            button.frame = CGRect(x: x, y: 0, width: width, height: 36)
            x += width + 8
        }
        chips.contentSize = CGSize(width: max(x - 8, 0), height: 36)
    }

    private func styleChips() {
        for (type, button) in chipButtons {
            let isOn = type == .reaction && isReaction
            button.backgroundColor = isOn ? .white : UIColor(white: 1, alpha: 0.14)
            button.tintColor = isOn ? .black : .white
        }
    }

    private func chipTapped(_ type: StoryWidgetType) {
        Haptics.play(.selection)
        guard type == .reaction else {
            onWidget?(type)

            return
        }

        isReaction.toggle()
        styleChips()
        setNeedsLayout()
        UIView.animate(withDuration: 0.2) {
            self.hint.alpha = self.isReaction ? 1 : 0
            self.layoutIfNeeded()
        }
    }

    @objc
    private func dimTapped() {
        onClose?()
    }
}

final class StoryEmojiCell: UICollectionViewCell {
    static let identifier = "StoryEmojiCell"

    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 34)
        contentView.addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }
}
