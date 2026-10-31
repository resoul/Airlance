import ChatHistory
import Foundation

struct SearchMatch: Sendable, Hashable {
    let messageID: String
    let quote: MessageQuote
}

extension ChatHistoryStore {
    func search(_ query: String, in id: String) async -> [SearchMatch] {
        let messages = history(for: id)?.messages ?? []

        return await Task.detached(priority: .userInitiated) {
            Self.matches(query, in: messages)
        }.value
    }

    nonisolated static func matches(_ query: String, in messages: [HistoryMessage]) -> [SearchMatch] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }

        return messages.compactMap { message in
            let text = message.content.text as NSString
            let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
            guard range.location != NSNotFound else {
                return nil
            }

            let quote = MessageQuote(text: text.substring(with: range), offset: range.location)

            return SearchMatch(messageID: message.id, quote: quote)
        }
    }
}
