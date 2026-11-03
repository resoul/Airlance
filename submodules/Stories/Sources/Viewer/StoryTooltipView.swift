import UIKit

final class StoryTooltipView: UIView {
    let action: StoryInteraction
    private let label = UILabel()
    private let chevron = UIImageView()

    init(title: String, action: StoryInteraction) {
        self.action = action
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.08, alpha: 0.86)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: configuration)
        chevron.tintColor = UIColor(white: 1, alpha: 0.7)
        chevron.contentMode = .center
        addSubview(label)
        addSubview(chevron)
        let width = ceil(label.intrinsicContentSize.width) + 48
        bounds = CGRect(x: 0, y: 0, width: width, height: 36)
        label.frame = CGRect(x: 14, y: 0, width: width - 40, height: 36)
        chevron.frame = CGRect(x: width - 28, y: 0, width: 16, height: 36)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func place(near target: CGRect, in container: CGRect, safeTop: CGFloat) {
        let x = min(max(target.midX, container.minX + bounds.width / 2 + 12), container.maxX - bounds.width / 2 - 12)
        let above = target.minY - 10 - bounds.height / 2
        let y = above > safeTop + 80 ? above : target.maxY + 10 + bounds.height / 2
        center = CGPoint(x: x, y: y)
    }

    func appear() {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func disappear() {
        UIView.animate(withDuration: 0.15) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}
