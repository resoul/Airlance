import UIKit

public enum AvatarColors {
    private static let palette: [(UIColor, UIColor)] = [
        (UIColor(red: 1.00, green: 0.52, blue: 0.40, alpha: 1), UIColor(red: 0.93, green: 0.33, blue: 0.27, alpha: 1)),
        (UIColor(red: 1.00, green: 0.75, blue: 0.36, alpha: 1), UIColor(red: 0.97, green: 0.57, blue: 0.22, alpha: 1)),
        (UIColor(red: 0.69, green: 0.55, blue: 1.00, alpha: 1), UIColor(red: 0.55, green: 0.38, blue: 0.95, alpha: 1)),
        (UIColor(red: 0.53, green: 0.86, blue: 0.44, alpha: 1), UIColor(red: 0.30, green: 0.73, blue: 0.33, alpha: 1)),
        (UIColor(red: 0.45, green: 0.85, blue: 0.89, alpha: 1), UIColor(red: 0.24, green: 0.69, blue: 0.80, alpha: 1)),
        (UIColor(red: 0.45, green: 0.72, blue: 1.00, alpha: 1), UIColor(red: 0.25, green: 0.53, blue: 0.95, alpha: 1)),
        (UIColor(red: 1.00, green: 0.55, blue: 0.75, alpha: 1), UIColor(red: 0.92, green: 0.35, blue: 0.58, alpha: 1)),
    ]

    public static func gradient(for id: String) -> [UIColor] {
        let pair = palette[Int(stableHash(id) % UInt64(palette.count))]

        return [pair.0, pair.1]
    }

    private static func stableHash(_ text: String) -> UInt64 {
        text.utf8.reduce(UInt64(5381)) { hash, byte in
            (hash &* 33) &+ UInt64(byte)
        }
    }
}
