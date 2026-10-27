@MainActor
public protocol PermissionProvider: Sendable {
    var permission: Permission { get }

    func status() async -> PermissionStatus
    func request() async
}
