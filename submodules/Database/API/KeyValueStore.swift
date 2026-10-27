import Observers

@MainActor
public protocol KeyValueStore: AnyObject {
    func value<Value>(for key: StorageKey<Value>) -> Value

    func observe<Value>(
        _ key: StorageKey<Value>,
        onChange: @escaping @MainActor (Value) -> Void
    ) -> ObservationToken

    @discardableResult
    func update<Value>(
        _ key: StorageKey<Value>,
        _ transform: @escaping @Sendable (inout Value) -> Void
    ) async throws -> Value
}
