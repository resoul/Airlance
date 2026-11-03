import Foundation

public enum AudioSessionQueue {
    private static let queue = DispatchQueue(label: "airlance.audio.session", qos: .userInitiated)

    public static func run(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }

    public static func perform<Result: Sendable>(_ work: @escaping @Sendable () -> Result) async -> Result {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: work())
            }
        }
    }
}
