import ChatHistory
import Foundation

@MainActor
final class FileDownloads {
    private var tasks: [String: Task<Void, Never>] = [:]

    func duration(for file: MessageFile) -> TimeInterval {
        min(max(Double(file.size) / 20_000, 0.9), 2.6)
    }

    func isActive(_ messageID: String) -> Bool {
        tasks[messageID] != nil
    }

    func start(_ messageID: String, duration: TimeInterval, onFinish: @escaping @MainActor () -> Void) {
        tasks[messageID]?.cancel()
        tasks[messageID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }

            self?.tasks[messageID] = nil
            onFinish()
        }
    }

    func cancel(_ messageID: String) {
        tasks[messageID]?.cancel()
        tasks[messageID] = nil
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks = [:]
    }
}
