import PermissionsAPI
import UserNotifications

public struct NotificationsPermission: PermissionProvider {
    public let permission = Permission.notifications

    public init() {}

    public func status() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .authorized:
            return .granted
        case .provisional, .ephemeral:
            return .limited
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    public func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
}
