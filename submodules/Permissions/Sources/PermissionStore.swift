import Observers
import PermissionsAPI
import UIKit

@MainActor
public final class PermissionStore: NSObject {
    public private(set) var snapshot: PermissionSnapshot

    private let providers: [Permission: any PermissionProvider]
    private let observers = ObserverList<PermissionSnapshot>()
    private var requests: [Permission: Task<PermissionResult, Never>] = [:]

    public init(providers: [any PermissionProvider]) {
        snapshot = PermissionSnapshot(permissions: providers.map(\.permission))
        self.providers = Dictionary(
            providers.map { provider in
                (provider.permission, provider)
            },
            uniquingKeysWith: { first, _ in
                first
            }
        )
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        Task {
            await refresh()
        }
    }

    public func status(_ permission: Permission) -> PermissionStatus? {
        snapshot.status(of: permission)
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (PermissionSnapshot) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(snapshot)

        return token
    }

    public func refresh() async {
        var snapshot = snapshot
        for permission in snapshot.permissions {
            if let provider = providers[permission] {
                snapshot.set(await provider.status(), for: permission)
            }
        }
        publish(snapshot)
    }

    @discardableResult
    public func request(_ permission: Permission) async -> PermissionResult {
        if let running = requests[permission] {
            return await running.value
        }

        guard let provider = providers[permission] else {
            return PermissionResult(status: .restricted, wasPrompted: false)
        }

        let task = Task {
            guard await provider.status() == .notDetermined else {
                return PermissionResult(status: await provider.status(), wasPrompted: false)
            }

            await provider.request()

            return PermissionResult(status: await provider.status(), wasPrompted: true)
        }
        requests[permission] = task
        let result = await task.value
        requests[permission] = nil

        var snapshot = snapshot
        snapshot.set(result.status, for: permission)
        publish(snapshot)

        return result
    }

    public func openSettings(for permission: Permission) {
        let address = switch permission {
        case .notifications:
            UIApplication.openNotificationSettingsURLString
        default:
            UIApplication.openSettingsURLString
        }
        guard let url = URL(string: address) else {
            return
        }

        UIApplication.shared.open(url)
    }

    private func publish(_ snapshot: PermissionSnapshot) {
        guard snapshot != self.snapshot else {
            return
        }

        self.snapshot = snapshot
        observers.notify(snapshot)
    }

    @objc
    private func applicationDidBecomeActive() {
        Task {
            await refresh()
        }
    }
}
