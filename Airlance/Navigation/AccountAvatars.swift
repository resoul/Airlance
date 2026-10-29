import AvatarUI
import UIKit

@MainActor
enum AccountAvatars {
    static func image(_ record: AccountRecord, strings: AppStrings, side: CGFloat) -> UIImage {
        descriptor(record, strings: strings)
            .placeholderImage(side: side, scale: UIScreen.main.scale)
            .withRenderingMode(.alwaysOriginal)
    }

    static func ringed(_ record: AccountRecord, strings: AppStrings, side: CGFloat, ring: UIColor) -> UIImage {
        let avatar = image(record, strings: strings, side: side - 6)
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let image = UIGraphicsImageRenderer(bounds: bounds).image { _ in
            ring.setStroke()
            let path = UIBezierPath(ovalIn: bounds.insetBy(dx: 0.75, dy: 0.75))
            path.lineWidth = 1.5
            path.stroke()
            avatar.draw(in: bounds.insetBy(dx: 3, dy: 3))
        }

        return image.withRenderingMode(.alwaysOriginal)
    }

    private static func descriptor(_ record: AccountRecord, strings: AppStrings) -> AvatarDescriptor {
        let name = strings.accountName(record)

        return AvatarDescriptor(id: record.id.rawValue, initials: AvatarDescriptor.initials(from: name))
    }
}
