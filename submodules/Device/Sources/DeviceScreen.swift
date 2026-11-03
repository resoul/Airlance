import UIKit

public enum ScreenCutout: Equatable, Sendable {
    case island(CGRect)
    case notch
    case none
}

@MainActor
public enum DeviceScreen {
    public static func cutout(in window: UIWindow) -> ScreenCutout {
        guard Device.kind == .phone, window.bounds.height > window.bounds.width else {
            return .none
        }

        let top = window.safeAreaInsets.top
        if top >= 59 {
            return .island(islandFrame(in: window, top: top))
        }

        return top > 24 ? .notch : .none
    }

    public static func island(in window: UIWindow) -> CGRect? {
        guard case .island(let frame) = cutout(in: window) else {
            return nil
        }

        return frame
    }

    private static func islandFrame(in window: UIWindow, top: CGFloat) -> CGRect {
        let size: CGSize
        let origin: CGFloat
        if top >= 62 {
            size = CGSize(width: 125.33, height: 36.67)
            origin = 14
        } else {
            size = CGSize(width: 126, height: 37.33)
            origin = 11.33
        }

        return CGRect(x: window.bounds.midX - size.width / 2, y: origin, width: size.width, height: size.height)
    }
}
