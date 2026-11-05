import Dispatch
import Network
import Observers

@MainActor
public final class NetworkMonitor {
    public private(set) var path = NetworkPath(kind: .other, isExpensive: false, isConstrained: false)

    private let monitor = NWPathMonitor()
    private let observers = ObserverList<NetworkPath>()

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            MainActor.assumeIsolated {
                self?.update(Self.networkPath(path))
            }
        }
        monitor.start(queue: .main)
    }

    deinit {
        monitor.cancel()
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (NetworkPath) -> Void) -> ObservationToken {
        observers.add(onChange)
    }

    private func update(_ next: NetworkPath) {
        guard next != path else {
            return
        }

        path = next
        observers.notify(next)
    }

    nonisolated private static func networkPath(_ path: NWPath) -> NetworkPath {
        NetworkPath(kind: kind(of: path), isExpensive: path.isExpensive, isConstrained: path.isConstrained)
    }

    nonisolated private static func kind(of path: NWPath) -> NetworkPath.Kind {
        guard path.status == .satisfied else {
            return .none
        }

        if path.usesInterfaceType(.wifi) {
            return .wifi
        }

        if path.usesInterfaceType(.cellular) {
            return .cellular
        }

        return path.usesInterfaceType(.wiredEthernet) ? .wired : .other
    }
}
