import CoreLocation
import PermissionsAPI

@MainActor
public final class LocationPermission: NSObject, PermissionProvider {
    public let permission = Permission.location

    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<Void, Never>] = []

    override public init() {
        super.init()
        manager.delegate = self
    }

    public func status() async -> PermissionStatus {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.accuracyAuthorization == .reducedAccuracy ? .limited : .granted
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
        guard manager.authorizationStatus == .notDetermined else {
            return
        }

        await withCheckedContinuation { continuation in
            waiting.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    private func authorizationChanged() {
        guard manager.authorizationStatus != .notDetermined else {
            return
        }

        let resumed = waiting
        waiting.removeAll()
        for continuation in resumed {
            continuation.resume()
        }
    }
}

extension LocationPermission: CLLocationManagerDelegate {
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            authorizationChanged()
        }
    }
}
