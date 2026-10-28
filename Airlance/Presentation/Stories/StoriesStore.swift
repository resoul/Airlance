import Observers

struct StorySummary: Sendable, Equatable {
    let peerID: String
    let name: String
    let total: Int
    var unseen: Int
    var isSelf = false
}

@MainActor
final class StoriesStore {
    private(set) var stories: [StorySummary]

    private let observers = ObserverList<[StorySummary]>()

    init(stories: [StorySummary]) {
        self.stories = stories
    }

    var ordered: [StorySummary] {
        let mine = stories.filter(\.isSelf)
        let others = stories.filter { story in
            !story.isSelf
        }
        let unseen = others.filter { story in
            story.unseen > 0
        }
        let seen = others.filter { story in
            story.unseen == 0
        }

        return mine + unseen + seen
    }

    func story(for peerID: String) -> StorySummary? {
        stories.first { story in
            story.peerID == peerID
        }
    }

    func markSeen(_ peerID: String, through item: Int) {
        guard let index = stories.firstIndex(where: { story in
            story.peerID == peerID
        }) else {
            return
        }

        let unseen = min(stories[index].unseen, max(stories[index].total - item - 1, 0))
        guard unseen != stories[index].unseen else {
            return
        }

        stories[index].unseen = unseen
        observers.notify(stories)
    }

    func observe(_ onChange: @escaping @MainActor @Sendable ([StorySummary]) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(stories)

        return token
    }
}
