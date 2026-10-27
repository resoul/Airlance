import os

public final class ObservationToken: Sendable {
    private let onCancel: OSAllocatedUnfairLock<(@Sendable () -> Void)?>

    public init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = OSAllocatedUnfairLock(initialState: onCancel)
    }

    deinit {
        cancel()
    }

    public func cancel() {
        let action = onCancel.withLock { action in
            defer {
                action = nil
            }

            return action
        }
        action?()
    }
}
