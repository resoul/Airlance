import Theme
import UIKit

final class WallpaperSwatch: UIControl {
    private static let size: CGFloat = 52

    let kind: ChatWallpaper
    private let gradient = CAGradientLayer()
    private let ring = CAShapeLayer()
    private let icon = UIImageView(image: UIImage(systemName: "circle.slash"))
    private var accent = UIColor.systemBlue

    var isChosen = false {
        didSet {
            updateRing()
        }
    }

    init(kind: ChatWallpaper) {
        self.kind = kind
        super.init(frame: .zero)
        gradient.startPoint = .zero
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = Self.size / 2 - 5
        layer.addSublayer(gradient)
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 2.5
        layer.addSublayer(ring)
        icon.contentMode = .center
        icon.isHidden = kind != .none
        addSubview(icon)
        accessibilityTraits = .button
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size),
            heightAnchor.constraint(equalToConstant: Self.size),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme, title: String) {
        accent = theme.colors.accent
        accessibilityLabel = title
        icon.tintColor = theme.colors.textSecondary
        let colors = kind.resolved(for: theme.appearance)?.colors ?? [theme.colors.surface, theme.colors.surface]
        gradient.colors = colors.map(\.cgColor)
        gradient.borderColor = theme.colors.separator.cgColor
        gradient.borderWidth = kind == .none ? 1 : 0
        updateRing()
    }

    private func updateRing() {
        ring.strokeColor = isChosen ? accent.cgColor : UIColor.clear.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds.insetBy(dx: 5, dy: 5)
        ring.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 1.25, dy: 1.25)).cgPath
        icon.frame = bounds
    }
}
