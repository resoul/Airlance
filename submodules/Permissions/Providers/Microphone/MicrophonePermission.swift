import AVFoundation
import PermissionsAPI

public struct MicrophonePermission: PermissionProvider {
    public let permission = Permission.microphone

    public init() {}

    public func status() async -> PermissionStatus {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                return .notDetermined
            @unknown default:
                return .denied
            }
        }

        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    public func request() async {
        if #available(iOS 17.0, *) {
            _ = await AVAudioApplication.requestRecordPermission()

            return
        }

        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { _ in
                continuation.resume()
            }
        }
    }
}
