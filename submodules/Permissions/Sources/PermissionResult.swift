import PermissionsAPI

public struct PermissionResult: Sendable {
    public let status: PermissionStatus
    public let wasPrompted: Bool
}
