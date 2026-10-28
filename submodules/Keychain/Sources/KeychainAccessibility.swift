import Security

public enum KeychainAccessibility: Sendable {
    case afterFirstUnlockThisDeviceOnly
    case whenUnlockedThisDeviceOnly

    var attribute: CFString {
        switch self {
        case .afterFirstUnlockThisDeviceOnly:
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlockedThisDeviceOnly:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
    }
}
