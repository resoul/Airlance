import Observers

@MainActor
public final class ConnectionStatusStore {
    public let network: NetworkMonitor
    public private(set) var status = ConnectionStatus.online

    private let leavingOnlineDelay: Duration
    private let observers = ObserverList<ConnectionStatus>()
    private var link = ServerLink.unused
    private var isUpdating = false
    private var pending: Task<Void, Never>?
    private var networkObservation: ObservationToken?

    private var target: ConnectionStatus {
        ConnectionStatus(path: network.path, link: link, isUpdating: isUpdating)
    }

    public init(network: NetworkMonitor, leavingOnlineDelay: Duration = .seconds(1)) {
        self.network = network
        self.leavingOnlineDelay = leavingOnlineDelay
        networkObservation = network.observe { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    public func observe(_ onChange: @escaping @MainActor @Sendable (ConnectionStatus) -> Void) -> ObservationToken {
        observers.add(onChange)
    }

    public func setLink(_ next: ServerLink) {
        guard next != link else {
            return
        }

        link = next
        refresh()
    }

    public func setUpdating(_ next: Bool) {
        guard next != isUpdating else {
            return
        }

        isUpdating = next
        refresh()
    }

    private func refresh() {
        let next = target
        guard next != status else {
            cancelPending()

            return
        }

        guard status == .online else {
            publish(next)

            return
        }

        guard pending == nil else {
            return
        }

        let delay = leavingOnlineDelay
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else {
                return
            }

            self.pending = nil
            self.publish(self.target)
        }
    }

    private func publish(_ next: ConnectionStatus) {
        cancelPending()
        guard next != status else {
            return
        }

        status = next
        observers.notify(next)
    }

    private func cancelPending() {
        pending?.cancel()
        pending = nil
    }
}
