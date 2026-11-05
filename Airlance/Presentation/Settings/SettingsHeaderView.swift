@preconcurrency import AsyncDisplayKit
import AvatarUI
import UIKit

struct ProfileFixture {
    static let current = ProfileFixture(
        id: "me",
        name: "Олена Коваль",
        phone: "+380 67 000 00 00",
        username: "@airlance"
    )

    let id: String
    let name: String
    let phone: String
    let username: String
}

struct SettingsHeaderGeometry {
    static let foldedHeight: CGFloat = 196
    static let avatarSize: CGFloat = 96
    static let avatarTop: CGFloat = 16

    var width: CGFloat = 0
    var topInset: CGFloat = 0
    var safeTop: CGFloat = 0
    var progress: CGFloat = 0
    var stretch: CGFloat = 0

    var openness: CGFloat {
        min(max(progress, 0), 1)
    }

    var photoHeight: CGFloat {
        width + safeTop
    }

    var extra: CGFloat {
        max(0, photoHeight - topInset - Self.foldedHeight)
    }

    var height: CGFloat {
        Self.foldedHeight + extra * max(progress, 0)
    }

    var folded: CGRect {
        CGRect(
            x: (width - Self.avatarSize) / 2,
            y: Self.avatarTop,
            width: Self.avatarSize,
            height: Self.avatarSize
        )
    }

    var photo: CGRect {
        let open = CGRect(x: 0, y: -topInset - stretch, width: width, height: photoHeight + stretch)

        return CGRect(
            x: Self.lerp(folded.minX, open.minX, openness),
            y: Self.lerp(folded.minY, open.minY, openness),
            width: Self.lerp(folded.width, open.width, openness),
            height: Self.lerp(folded.height, open.height, openness)
        )
    }

    var foldedAndExtraBottom: CGFloat {
        Self.foldedHeight + extra
    }

    var cornerRadius: CGFloat {
        Self.lerp(Self.avatarSize / 2, 0, openness)
    }

    static func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}

final class SettingsHeaderView: UIView {
    var onPhotoTap: (@MainActor (CGFloat) -> Void)?
    var onPhotoSwipe: (@MainActor (Bool) -> Void)?

    private var swipes: PhotoSwipes?
    private let photo = UIView()
    private let avatar = AvatarNode()
    private let shade = CAGradientLayer()
    private let segments = UIStackView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private var nameColor = UIColor.label
    private var detailColor = UIColor.secondaryLabel

    var nameBottom: CGFloat {
        nameLabel.frame.maxY
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        avatar.isUserInteractionEnabled = false
        photo.clipsToBounds = true
        photo.addSubview(avatar.view)
        photo.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped(_:))))
        swipes = PhotoSwipes(view: photo)
        swipes?.onSwipe = { [weak self] forward in
            self?.onPhotoSwipe?(forward)
        }
        shade.colors = [UIColor(white: 0, alpha: 0.35), .clear, .clear, UIColor(white: 0, alpha: 0.5)].map(\.cgColor)
        shade.locations = [0, 0.25, 0.6, 1]
        photo.layer.addSublayer(shade)
        segments.axis = .horizontal
        segments.spacing = 4
        segments.distribution = .fillEqually
        addSubview(photo)
        addSubview(segments)
        addSubview(nameLabel)
        addSubview(detailLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(_ profile: MyProfile) {
        nameLabel.text = profile.fullName
        detailLabel.text = profile.contactLine
    }

    func showPhoto(_ descriptor: AvatarDescriptor, index: Int, count: Int, expanded: Bool) {
        avatar.apply(descriptor, presentation: expanded ? .gallery : .profile)
        while segments.arrangedSubviews.count < count {
            let bar = UIView()
            bar.layer.cornerRadius = 1.5
            segments.addArrangedSubview(bar)
        }
        for (position, bar) in segments.arrangedSubviews.enumerated() {
            bar.isHidden = position >= count
            bar.backgroundColor = UIColor(white: 1, alpha: position == index ? 1 : 0.4)
        }
        segments.isHidden = count < 2
    }

    func apply(_ presentation: PresentationData) {
        let theme = presentation.theme

        backgroundColor = theme.colors.background
        nameLabel.font = theme.fonts.title
        detailLabel.font = theme.fonts.subheadline
        nameColor = theme.colors.textPrimary
        detailColor = theme.colors.textSecondary
    }

    func layout(_ geometry: SettingsHeaderGeometry) {
        let openness = geometry.openness
        photo.frame = geometry.photo
        photo.layer.cornerRadius = geometry.cornerRadius
        avatar.contentCornerRadius = geometry.cornerRadius
        avatar.frame = photo.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shade.frame = photo.bounds
        shade.opacity = Float(openness)
        CATransaction.commit()
        let segmentsTop = -geometry.topInset - geometry.stretch + geometry.safeTop + 2
        segments.frame = CGRect(x: 8, y: segmentsTop, width: geometry.width - 16, height: 3)
        segments.alpha = max(0, min(1, (geometry.progress - 0.85) / 0.15))
        layoutTitles(geometry)
    }

    private func layoutTitles(_ geometry: SettingsHeaderGeometry) {
        let width = geometry.width
        let openness = geometry.openness
        let limit = CGSize(width: width - 32, height: .greatestFiniteMagnitude)
        let nameSize = nameLabel.sizeThatFits(limit)
        let detailSize = detailLabel.sizeThatFits(limit)
        let nameWidth = min(nameSize.width, limit.width)
        let detailWidth = min(detailSize.width, limit.width)
        let foldedName = geometry.folded.maxY + 12
        let openDetail = geometry.foldedAndExtraBottom - 12 - detailSize.height
        let openName = openDetail - 4 - nameSize.height
        nameLabel.frame = CGRect(
            x: SettingsHeaderGeometry.lerp((width - nameWidth) / 2, 16, openness),
            y: SettingsHeaderGeometry.lerp(foldedName, openName, openness),
            width: nameWidth,
            height: nameSize.height
        )
        detailLabel.frame = CGRect(
            x: SettingsHeaderGeometry.lerp((width - detailWidth) / 2, 16, openness),
            y: SettingsHeaderGeometry.lerp(foldedName + nameSize.height + 4, openDetail, openness),
            width: detailWidth,
            height: detailSize.height
        )
        let onPhoto = openness > 0.5
        nameLabel.textColor = onPhoto ? .white : nameColor
        detailLabel.textColor = onPhoto ? UIColor(white: 1, alpha: 0.85) : detailColor
    }

    func slidePhoto(forward: Bool) {
        PhotoSwipes.slide(avatar.layer, forward: forward)
    }

    func shakePhoto(forward: Bool) {
        let shift: CGFloat = forward ? -10 : 10
        let shake = CAKeyframeAnimation(keyPath: "transform")
        let nudged = [1, -0.35].map { step in
            CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: shift * step, y: 0).scaledBy(x: 1.05, y: 1.05)
            )
        }
        shake.values = [CATransform3DIdentity] + nudged + [CATransform3DIdentity]
        shake.keyTimes = [0, 0.35, 0.7, 1]
        shake.duration = 0.35
        shake.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 3)
        avatar.layer.add(shake, forKey: "edge")
    }

    @objc
    private func photoTapped(_ gesture: UITapGestureRecognizer) {
        onPhotoTap?(gesture.location(in: photo).x / max(photo.bounds.width, 1))
    }
}
