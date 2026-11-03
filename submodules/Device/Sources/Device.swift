import UIKit

@MainActor
public enum Device {
    public enum Kind: Sendable {
        case phone
        case pad
        case mac
        case other
    }

    public static var kind: Kind {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            .phone
        case .pad:
            ProcessInfo.processInfo.isiOSAppOnMac ? .mac : .pad
        case .mac:
            .mac
        default:
            .other
        }
    }
}
