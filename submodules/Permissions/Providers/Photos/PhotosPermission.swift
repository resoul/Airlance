import PermissionsAPI
import Photos

public struct PhotosPermission: PermissionProvider {
    public let permission = Permission.photos

    public init() {}

    public func status() async -> PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized:
            .granted
        case .limited:
            .limited
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        @unknown default:
            .denied
        }
    }

    public func request() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
}
