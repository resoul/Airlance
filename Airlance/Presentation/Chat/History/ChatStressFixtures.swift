import Foundation

enum ChatStressFixtures {
    static let chatID = "stress"
    static let messageCount = 30_000
    static let feedInterval: ClosedRange<TimeInterval> = 0.3...0.9

    static func count(for chatID: String) -> Int? {
        isStress(chatID) ? messageCount : nil
    }

    static func isStress(_ chatID: String) -> Bool {
        chatID == self.chatID
    }
}
