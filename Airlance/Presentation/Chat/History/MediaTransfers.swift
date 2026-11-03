import Foundation
import Observers

struct TransferKey: Hashable, Sendable {
    let chatID: String
    let messageID: String
}

struct TransferProgress: Hashable, Sendable {
    enum Direction: Sendable {
        case upload
        case download
    }

    let direction: Direction
    var done: Int64
    let total: Int64

    var fraction: Double {
        total > 0 ? min(1, Double(done) / Double(total)) : 0
    }
}

struct TransferEvent: Sendable {
    let key: TransferKey
    let progress: TransferProgress?
}

@MainActor
final class MediaTransfers {
    private struct Active {
        var progress: TransferProgress
        let speed: Double
        let onFinish: @MainActor () -> Void
    }

    private static let tick: TimeInterval = 0.05
    private static let shortest: TimeInterval = 0.8
    private static let longest: TimeInterval = 6

    private var active: [TransferKey: Active] = [:]
    private var ticker: Task<Void, Never>?
    private let observers = ObserverList<TransferEvent>()

    func observe(_ onEvent: @escaping @MainActor @Sendable (TransferEvent) -> Void) -> ObservationToken {
        observers.add(onEvent)
    }

    func progress(_ key: TransferKey) -> TransferProgress? {
        active[key]?.progress
    }

    func start(
        _ key: TransferKey,
        direction: TransferProgress.Direction,
        total: Int64,
        onFinish: @escaping @MainActor () -> Void
    ) {
        let nominal: Double = direction == .upload ? .random(in: 600_000...1_500_000) : .random(in: 900_000...2_500_000)
        let bytes = Double(max(1, total))
        let speed = min(bytes / Self.shortest, max(bytes / Self.longest, nominal))
        let progress = TransferProgress(direction: direction, done: 0, total: max(1, total))
        active[key] = Active(progress: progress, speed: speed, onFinish: onFinish)
        observers.notify(TransferEvent(key: key, progress: progress))
        startTicker()
    }

    func cancel(_ key: TransferKey) {
        guard active.removeValue(forKey: key) != nil else {
            return
        }

        observers.notify(TransferEvent(key: key, progress: nil))
    }

    func cancelAll() {
        for key in active.keys {
            cancel(key)
        }
        ticker?.cancel()
        ticker = nil
    }

    private func startTicker() {
        guard ticker == nil else {
            return
        }

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.tick * 1_000_000_000))
                guard let self, !Task.isCancelled, self.step() else {
                    break
                }
            }
            self?.ticker = nil
        }
    }

    private func step() -> Bool {
        guard DemoNetwork.shared.isOnline else {
            return !active.isEmpty
        }

        for key in Array(active.keys) {
            guard var transfer = active[key] else {
                continue
            }

            let chunk = transfer.speed * Self.tick * .random(in: 0.5...1.5)
            transfer.progress.done = min(transfer.progress.total, transfer.progress.done + Int64(chunk))
            guard transfer.progress.done < transfer.progress.total else {
                active[key] = nil
                observers.notify(TransferEvent(key: key, progress: nil))
                transfer.onFinish()
                continue
            }

            active[key] = transfer
            observers.notify(TransferEvent(key: key, progress: transfer.progress))
        }

        return !active.isEmpty
    }
}
