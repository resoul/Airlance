public enum ServerLink: Sendable, Equatable {
    case unused
    case connecting
    case connected
}

public enum ConnectionStatus: Sendable, Equatable {
    case waitingForNetwork
    case connecting
    case updating
    case online

    public init(path: NetworkPath, link: ServerLink, isUpdating: Bool) {
        if !path.isConnected {
            self = .waitingForNetwork
        } else if link == .connecting {
            self = .connecting
        } else if link == .connected, isUpdating {
            self = .updating
        } else {
            self = .online
        }
    }
}
