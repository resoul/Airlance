import PermissionsAPI

public struct PermissionSnapshot: Equatable, Sendable {
    public let permissions: [Permission]

    private var statuses: [Permission: PermissionStatus] = [:]

    init(permissions: [Permission]) {
        self.permissions = permissions
    }

    public func status(of permission: Permission) -> PermissionStatus? {
        statuses[permission]
    }

    mutating func set(_ status: PermissionStatus, for permission: Permission) {
        statuses[permission] = status
    }
}
