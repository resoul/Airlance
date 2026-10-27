import os

public final class ObserverList<Value: Sendable>: Sendable {
    public typealias Observer = @MainActor @Sendable (Value) -> Void

    private struct State {
        var nextID = 0
        var observers: [Int: Observer] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    public func add(_ observer: @escaping Observer) -> ObservationToken {
        let id = state.withLock { state in
            let id = state.nextID
            state.nextID += 1
            state.observers[id] = observer

            return id
        }

        return ObservationToken { [state] in
            state.withLock { state in
                state.observers[id] = nil
            }
        }
    }

    @MainActor
    public func notify(_ value: Value) {
        let observers = state.withLock { state in
            Array(state.observers.values)
        }

        for observer in observers {
            observer(value)
        }
    }
}
