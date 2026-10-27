public enum PermissionStatus: Sendable, Equatable {
    case notDetermined
    case granted
    case limited
    case denied
    case restricted

    public var allowsUse: Bool {
        self == .granted || self == .limited
    }
}
