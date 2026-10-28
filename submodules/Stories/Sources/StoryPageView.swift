@preconcurrency import AsyncDisplayKit
import AvatarUI
import UIKit

@MainActor
final class StoryPageView: UIView {
    let author: StoryAuthor
    let media = StoryMediaView()
    let shade = UIView()
    let closeButton = UIButton(type: .system)

    var safeTop: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    private(set) var itemIndex = 0

    private let topGradient = CAGradientLayer()
    private let progressView = StoryProgressView()
    private let avatar = AvatarNode()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()

    var item: StoryItem? {
        author.items.indices.contains(itemIndex) ? author.items[itemIndex] : nil
    }

    init(author: StoryAuthor) {
        self.author = author
        super.init(frame: .zero)
        backgroundColor = .black
        addSubview(media)
        topGradient.colors = [UIColor(white: 0, alpha: 0.5).cgColor, UIColor.clear.cgColor]
        layer.addSublayer(topGradient)
        progressView.setCount(author.items.count)
        addSubview(progressView)
        avatar.apply(author.peer.avatar, presentation: .still)
        addSubview(avatar.view)
        nameLabel.text = author.peer.title
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .white
        addSubview(nameLabel)
        timeLabel.font = .systemFont(ofSize: 13)
        timeLabel.textColor = UIColor(white: 1, alpha: 0.7)
        addSubview(timeLabel)
        let symbol = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbol), for: .normal)
        closeButton.tintColor = .white
        addSubview(closeButton)
        shade.backgroundColor = .black
        shade.alpha = 0
        shade.isUserInteractionEnabled = false
        addSubview(shade)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ index: Int) {
        guard author.items.indices.contains(index) else {
            return
        }

        itemIndex = index
        let item = author.items[index]
        timeLabel.text = item.timeText
        progressView.set(index: index, progress: 0)
        media.show(item)
        setNeedsLayout()
    }

    func setProgress(_ progress: CGFloat) {
        progressView.set(index: itemIndex, progress: progress)
        media.update()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        media.frame = bounds
        shade.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        topGradient.frame = CGRect(x: 0, y: 0, width: bounds.width, height: safeTop + 96)
        CATransaction.commit()

        let top = safeTop + 8
        progressView.frame = CGRect(x: 8, y: top, width: bounds.width - 16, height: 4)
        let rowY = progressView.frame.maxY + 10
        avatar.frame = CGRect(x: 12, y: rowY, width: 32, height: 32)
        let textX = avatar.frame.maxX + 8
        let nameWidth = min(ceil(nameLabel.intrinsicContentSize.width), bounds.width - textX - 120)
        nameLabel.frame = CGRect(x: textX, y: rowY, width: nameWidth, height: 32)
        timeLabel.frame = CGRect(x: nameLabel.frame.maxX + 8, y: rowY, width: 80, height: 32)
        closeButton.frame = CGRect(x: bounds.width - 52, y: rowY - 6, width: 44, height: 44)
    }
}
