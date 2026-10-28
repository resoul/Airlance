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

final class SettingsHeaderView: UIView {
    static let height: CGFloat = 196

    private let avatar = AvatarNode()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let profile = ProfileFixture.current
        avatar.apply(PeerAvatars.descriptor(id: profile.id, name: profile.name), presentation: .profile)
        nameLabel.text = profile.name
        nameLabel.textAlignment = .center
        detailLabel.text = "\(profile.phone) · \(profile.username)"
        detailLabel.textAlignment = .center
        addSubview(avatar.view)
        addSubview(nameLabel)
        addSubview(detailLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        let theme = presentation.theme

        backgroundColor = theme.colors.background
        nameLabel.font = theme.fonts.title
        nameLabel.textColor = theme.colors.textPrimary
        detailLabel.font = theme.fonts.subheadline
        detailLabel.textColor = theme.colors.textSecondary
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size: CGFloat = 96
        avatar.frame = CGRect(x: (bounds.width - size) / 2, y: 16, width: size, height: size)

        let nameHeight = ceil(nameLabel.font.lineHeight)
        nameLabel.frame = CGRect(x: 16, y: avatar.frame.maxY + 12, width: bounds.width - 32, height: nameHeight)
        detailLabel.frame = CGRect(
            x: 16,
            y: nameLabel.frame.maxY + 4,
            width: bounds.width - 32,
            height: ceil(detailLabel.font.lineHeight)
        )
    }
}
