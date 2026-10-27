import Contacts
import PermissionsAPI

public struct ContactsPermission: PermissionProvider {
    public let permission = Permission.contacts

    public init() {}

    public func status() async -> PermissionStatus {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if #available(iOS 18.0, *), status == .limited {
            return .limited
        }

        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    public func request() async {
        _ = try? await CNContactStore().requestAccess(for: .contacts)
    }
}
