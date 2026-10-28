import CameraPermission
import ContactsPermission
import LocationPermission
import MicrophonePermission
import NotificationsPermission
import PermissionsAPI
import PhotosPermission

enum AppPermissions {
    @MainActor
    static func makeProviders() -> [any PermissionProvider] {
        [
            NotificationsPermission(),
            CameraPermission(),
            MicrophonePermission(),
            PhotosPermission(),
            ContactsPermission(),
            LocationPermission(),
        ]
    }
}
