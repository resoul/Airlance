import CameraPermission
import ContactsPermission
import LocationPermission
import MicrophonePermission
import NotificationsPermission
import PermissionsAPI
import PhotosPermission
import SpeechPermission

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
            SpeechPermission(),
        ]
    }
}
