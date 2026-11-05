import Connectivity

extension ConnectionStatus {
    func title(_ strings: AppStrings) -> String? {
        switch self {
        case .waitingForNetwork:
            strings.connectionWaitingForNetwork
        case .connecting:
            strings.connectionConnecting
        case .updating:
            strings.connectionUpdating
        case .online:
            nil
        }
    }
}
