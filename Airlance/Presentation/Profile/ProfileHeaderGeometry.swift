import CoreGraphics

struct ProfileHeaderGeometry {
    static let avatarSize: CGFloat = 100
    static let buttonHeight: CGFloat = 58

    var width: CGFloat = 0
    var navHeight: CGFloat = 0
    var safeTop: CGFloat = 0
    var progress: CGFloat = 0
    var stretch: CGFloat = 0
    var infoHeight: CGFloat = 0

    var avatarTop: CGFloat {
        navHeight + 4
    }

    var nameBottom: CGFloat {
        avatarTop + Self.avatarSize + 66
    }

    var extra: CGFloat {
        max(0, width - nameBottom)
    }

    var openness: CGFloat {
        min(max(progress, 0), 1)
    }

    var expansion: CGFloat {
        extra * openness
    }

    var buttonsTop: CGFloat {
        nameBottom + 14 + expansion
    }

    var infoTop: CGFloat {
        buttonsTop + Self.buttonHeight + 16
    }

    var contentHeight: CGFloat {
        infoTop + infoHeight + 20
    }

    var foldedPhoto: CGRect {
        CGRect(x: (width - Self.avatarSize) / 2, y: avatarTop, width: Self.avatarSize, height: Self.avatarSize)
    }

    var openPhoto: CGRect {
        let bottom = nameBottom + expansion
        let height = max(width, bottom + stretch)

        return CGRect(x: 0, y: bottom - height, width: width, height: height)
    }

    var photo: CGRect {
        let folded = foldedPhoto
        let open = openPhoto
        let value = min(max(progress, 0), 1.08)

        return CGRect(
            x: folded.minX + (open.minX - folded.minX) * value,
            y: folded.minY + (open.minY - folded.minY) * value,
            width: folded.width + (open.width - folded.width) * value,
            height: folded.height + (open.height - folded.height) * value
        )
    }

    var photoCornerRadius: CGFloat {
        Self.avatarSize / 2 * max(0, 1 - min(max(progress, 0), 1.08) * 1.2)
    }

    static func lerp(_ from: CGPoint, _ to: CGPoint, _ fraction: CGFloat) -> CGPoint {
        CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction)
    }
}
