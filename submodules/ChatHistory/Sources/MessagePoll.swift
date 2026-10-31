import Foundation

public struct MessagePoll: Sendable, Hashable {
    public struct Option: Sendable, Hashable {
        public let text: String
        public var votes: Int
        public var voters: [MessageCommenter] = []

        public init(text: String, votes: Int = 0) {
            self.text = text
            self.votes = votes
        }
    }

    public let question: String
    public var options: [Option]
    public let isAnonymous: Bool
    public let allowsMultiple: Bool
    public var chosen: Set<Int> = []
    public var voters: Int
    public var isClosed = false
    public var correctOption: Int?
    public var explanation: String?
    public var closeDate: Date?

    public init(question: String, options: [Option], isAnonymous: Bool, allowsMultiple: Bool, voters: Int = 0) {
        self.question = question
        self.options = options
        self.isAnonymous = isAnonymous
        self.allowsMultiple = allowsMultiple
        self.voters = voters
    }

    public var isQuiz: Bool {
        correctOption != nil
    }

    public var canRetract: Bool {
        hasVoted && !isClosed && !isQuiz
    }

    public var answeredCorrectly: Bool? {
        guard isQuiz, hasVoted, let correctOption else {
            return nil
        }

        return chosen == [correctOption]
    }

    public var hasVoted: Bool {
        !chosen.isEmpty
    }

    public var showsResults: Bool {
        hasVoted || isClosed
    }

    public func share(of index: Int) -> Double {
        guard voters > 0, options.indices.contains(index) else {
            return 0
        }

        return Double(options[index].votes) / Double(voters)
    }

    public mutating func vote(_ indices: Set<Int>, by voter: MessageCommenter? = nil) {
        let valid = indices.filter(options.indices.contains)
        let isSingle = valid.count == 1
        guard !hasVoted, !isClosed, !valid.isEmpty, (allowsMultiple && !isQuiz) || isSingle else {
            return
        }

        for index in valid {
            options[index].votes += 1
            if let voter, !isAnonymous {
                options[index].voters.insert(voter, at: 0)
            }
        }
        chosen = valid
        voters += 1
    }

    public mutating func retract(by voter: MessageCommenter? = nil) {
        guard canRetract else {
            return
        }

        for index in chosen {
            options[index].votes = max(0, options[index].votes - 1)
            options[index].voters.removeAll { person in
                person.id == voter?.id
            }
        }
        chosen = []
        voters = max(0, voters - 1)
    }
}
