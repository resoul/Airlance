import UIKit

extension UIColor {
    public convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    public var rgb: UInt32 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let channels = [red, green, blue].map { component in
            UInt32(max(0, min(255, (component * 255).rounded())))
        }

        return channels[0] << 16 | channels[1] << 8 | channels[2]
    }
}
