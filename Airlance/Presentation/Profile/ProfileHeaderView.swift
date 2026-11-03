@preconcurrency import AsyncDisplayKit
import AvatarUI
import MusicPlayer
import Theme
import UIKit

final class ProfileHeaderView: UIView {
    var onPhotoTap: (@MainActor (Bool) -> Void)?
    var onAction: (@MainActor (ProfileAction, ProfileActionButton) -> Void)?

    let photo = UIView()
    let info = ProfileInfoCard()
    let audioPanel = AudioPanelView()
    private let audioCard = FloatingCard()

    private let avatar = AvatarNode()
    private let shade = CAGradientLayer()
    private let segments = UIStackView()
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let dock = ProfileActionDock()
    private let buttons = ProfileAction.allCases.map { action in
        ProfileActionButton(action: action)
    }

    private var textColor = UIColor.label
    private var statusColor = UIColor.secondaryLabel

    override init(frame: CGRect) {
        super.init(frame: frame)
        avatar.isUserInteractionEnabled = false
        avatar.contentCornerRadius = ProfileHeaderGeometry.avatarSize / 2
        photo.addSubview(avatar.view)
        photo.clipsToBounds = true
        photo.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped(_:))))
        shade.colors = [UIColor(white: 0, alpha: 0.35), .clear, .clear, UIColor(white: 0, alpha: 0.5)].map(\.cgColor)
        shade.locations = [0, 0.25, 0.6, 1]
        photo.layer.addSublayer(shade)
        segments.axis = .horizontal
        segments.spacing = 4
        segments.distribution = .fillEqually
        addSubview(photo)
        addSubview(segments)
        addSubview(nameLabel)
        addSubview(statusLabel)
        audioPanel.showsSeparator = false
        audioCard.content.addSubview(audioPanel)
        audioCard.setRows([(audioPanel, AudioPanelView.height)])
        addSubview(audioCard)
        addSubview(dock)
        for button in buttons {
            button.addAction(
                UIAction { [weak self, weak button] _ in
                    guard let self, let button else {
                        return
                    }

                    self.onAction?(button.action, button)
                },
                for: .touchUpInside
            )
            dock.addSubview(button)
        }
        addSubview(info)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(name: String, status: String, isOnline: Bool, presentation: PresentationData) {
        let theme = presentation.theme
        nameLabel.text = name
        nameLabel.font = theme.fonts.title.withSize(max(24, theme.fonts.title.pointSize))
        statusLabel.text = status
        statusLabel.font = theme.fonts.subheadline.withSize(max(15, theme.fonts.subheadline.pointSize))
        textColor = theme.colors.textPrimary
        statusColor = isOnline ? theme.colors.accent : theme.colors.textSecondary
        backgroundColor = theme.groupedBackground
        dock.apply(theme)
        audioCard.apply(theme)
    }

    func apply(action: ProfileAction, symbol: String, title: String, theme: AppTheme) {
        let button = buttons.first { button in
            button.action == action
        }
        button?.apply(symbol: symbol, title: title, theme: theme)
    }

    func showPhoto(_ descriptor: AvatarDescriptor, index: Int, count: Int, expanded: Bool) {
        avatar.apply(descriptor, presentation: expanded ? .gallery : .profile)
        while segments.arrangedSubviews.count < count {
            let bar = UIView()
            bar.layer.cornerRadius = 1.5
            segments.addArrangedSubview(bar)
        }
        for (position, bar) in segments.arrangedSubviews.enumerated() {
            bar.backgroundColor = UIColor(white: 1, alpha: position == index ? 1 : 0.4)
        }
        segments.isHidden = count < 2
    }

    func layout(_ geometry: ProfileHeaderGeometry) {
        let width = geometry.width
        let openness = geometry.openness
        photo.frame = geometry.photo
        photo.layer.cornerRadius = geometry.photoCornerRadius
        avatar.contentCornerRadius = geometry.photoCornerRadius
        avatar.frame = photo.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shade.frame = photo.bounds
        shade.opacity = Float(openness)
        CATransaction.commit()

        layoutTitles(geometry)
        let segmentsTop = max(photo.frame.minY, -geometry.stretch) + geometry.safeTop + 48
        segments.frame = CGRect(x: 8, y: segmentsTop, width: width - 16, height: 3)
        segments.alpha = max(0, min(1, (geometry.progress - 0.85) / 0.15))

        let dockHeight = ProfileHeaderGeometry.buttonHeight
        dock.frame = CGRect(x: 16, y: geometry.buttonsTop, width: width - 32, height: dockHeight)
        info.frame = CGRect(x: 16, y: geometry.infoTop, width: width - 32, height: geometry.infoHeight)
        audioCard.isHidden = geometry.audioHeight <= 0
        audioCard.frame = CGRect(x: 16, y: geometry.audioTop, width: width - 32, height: geometry.audioHeight)
    }

    private func layoutTitles(_ geometry: ProfileHeaderGeometry) {
        let width = geometry.width
        let openness = geometry.openness
        let folded = geometry.foldedPhoto
        let bottom = geometry.nameBottom + geometry.expansion
        let nameSize = nameLabel.sizeThatFits(CGSize(width: width - 32, height: .greatestFiniteMagnitude))
        let statusSize = statusLabel.sizeThatFits(CGSize(width: width - 32, height: .greatestFiniteMagnitude))
        nameLabel.frame.size = CGSize(width: min(nameSize.width, width - 32), height: nameSize.height)
        statusLabel.frame.size = CGSize(width: min(statusSize.width, width - 32), height: statusSize.height)
        nameLabel.frame.origin = ProfileHeaderGeometry.lerp(
            CGPoint(x: (width - nameLabel.frame.width) / 2, y: folded.maxY + 12),
            CGPoint(x: 16, y: bottom - 60 - geometry.titleLift),
            openness
        )
        statusLabel.frame.origin = ProfileHeaderGeometry.lerp(
            CGPoint(x: (width - statusLabel.frame.width) / 2, y: folded.maxY + 44),
            CGPoint(x: 16, y: bottom - 30 - geometry.titleLift),
            openness
        )
        let onPhoto = openness > 0.5
        nameLabel.textColor = onPhoto ? .white : textColor
        statusLabel.textColor = onPhoto ? UIColor(white: 1, alpha: 0.8) : statusColor
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
        onPhotoTap?(gesture.location(in: photo).x > photo.bounds.width / 2)
    }
}
