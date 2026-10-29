import UIKit

@MainActor
public enum DynamicIslandGeometry {
    public static func hasIsland(in window: UIWindow) -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone
            && window.safeAreaInsets.top >= 59
            && window.bounds.height > window.bounds.width
    }

    public static func frame(in window: UIWindow) -> CGRect {
        let size: CGSize
        let top: CGFloat
        if window.safeAreaInsets.top >= 62 {
            size = CGSize(width: 125.33, height: 36.67)
            top = 14
        } else {
            size = CGSize(width: 126, height: 37.33)
            top = 11.33
        }

        return CGRect(x: window.bounds.midX - size.width / 2, y: top, width: size.width, height: size.height)
    }
}
