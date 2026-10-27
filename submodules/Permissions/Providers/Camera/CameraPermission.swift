import AVFoundation
import PermissionsAPI

public struct CameraPermission: PermissionProvider {
    public let permission = Permission.camera

    public init() {}

    public func status() async -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            .granted
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
        _ = await AVCaptureDevice.requestAccess(for: .video)
    }
}
