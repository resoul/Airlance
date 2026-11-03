import Foundation

public struct SubtitleWord: Sendable, Hashable, Codable {
    public var text: String
    public var start: TimeInterval
    public var end: TimeInterval

    public init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }
}

public struct SubtitlePhrase: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public var words: [SubtitleWord]

    public init(words: [SubtitleWord]) {
        id = UUID()
        self.words = words
    }

    public var start: TimeInterval {
        words.first?.start ?? 0
    }

    public var end: TimeInterval {
        words.last?.end ?? 0
    }

    public var text: String {
        words.map(\.text).joined(separator: " ")
    }

    public mutating func setText(_ text: String) {
        let parts = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let start = start
        let length = max(end - start, 0.2)
        let total = max(parts.reduce(0) { sum, part in
            sum + part.count
        }, 1)
        var cursor = start
        words = parts.map { part in
            let duration = length * Double(part.count) / Double(total)
            defer {
                cursor += duration
            }

            return SubtitleWord(text: part, start: cursor, end: cursor + duration)
        }
    }
}

public enum SubtitleStyle: String, CaseIterable, Sendable, Codable {
    case shadow
    case plate
    case pop
}

public struct Subtitles: Sendable, Hashable, Codable {
    public static let defaultPosition: CGFloat = 0.72

    private static let pause: TimeInterval = 0.7
    private static let maxWords = 6
    private static let maxCharacters = 28

    public var phrases: [SubtitlePhrase]
    public var style = SubtitleStyle.shadow
    public var position = Subtitles.defaultPosition
    public var isShown = true

    public var isEmpty: Bool {
        phrases.isEmpty
    }

    public init(phrases: [SubtitlePhrase]) {
        self.phrases = phrases
    }

    public init(words: [SubtitleWord]) {
        var phrases: [SubtitlePhrase] = []
        var current: [SubtitleWord] = []
        for word in words {
            if let last = current.last, Self.breaks(after: last, current: current, next: word) {
                phrases.append(SubtitlePhrase(words: current))
                current = []
            }
            current.append(word)
        }
        if !current.isEmpty {
            phrases.append(SubtitlePhrase(words: current))
        }
        self.phrases = phrases
    }

    public func active(at time: TimeInterval) -> (phrase: SubtitlePhrase, word: Int?)? {
        guard let phrase = phrases.first(where: { phrase in
            time >= phrase.start && time < phrase.end + 0.3
        }) else {
            return nil
        }

        let word = phrase.words.lastIndex { word in
            word.start <= time
        }

        return (phrase, word)
    }

    private static func breaks(after last: SubtitleWord, current: [SubtitleWord], next: SubtitleWord) -> Bool {
        let characters = current.reduce(next.text.count) { sum, word in
            sum + word.text.count + 1
        }
        let endsSentence = last.text.last.map { character in
            ".?!".contains(character)
        } ?? false

        return next.start - last.end > pause || current.count >= maxWords || characters > maxCharacters || endsSentence
    }
}
