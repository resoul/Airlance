import Foundation
import Observers
import Stories

struct PublishedStory: Sendable, Equatable {
    enum Media: Sendable, Equatable {
        case photo(URL)
        case video(URL)
    }

    let id: String
    let media: Media
    let audience: StoryAudience
    var date: Date
    var widgets: [StoryEntity] = []
    var aspect: CGSize?
    var draft: StoryDraft?

    var settings: StoryPublishSettings {
        draft?.settings ?? StoryPublishSettings()
    }

    var url: URL {
        switch media {
        case .photo(let url), .video(let url):
            url
        }
    }

    func isLive(at now: Date) -> Bool {
        settings.isPinned || now < date + settings.lifetime.interval
    }
    static func == (left: PublishedStory, right: PublishedStory) -> Bool {
        left.id == right.id && left.media == right.media && left.date == right.date
            && left.draft?.createdAt == right.draft?.createdAt
    }
}

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
    private(set) var published: [PublishedStory] = []
    var onSeed: (@MainActor (StorySeed) -> Void)?

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

    func publish(_ story: PublishedStory) {
        if let index = published.firstIndex(where: { item in
            item.id == story.id
        }) {
            let old = published[index]
            let kept = Set((story.draft?.files ?? []) + [story.url])
            StoriesStore.remove(([old.url] + (old.draft?.files ?? [])).filter { url in
                !kept.contains(url)
            })
            var story = story
            story.date = old.date
            published[index] = story
            observers.notify(stories)

            return
        }

        published.append(story)
        if let index = stories.firstIndex(where: \.isSelf) {
            let mine = stories[index]
            stories[index] = StorySummary(
                peerID: mine.peerID,
                name: mine.name,
                total: mine.total + 1,
                unseen: mine.unseen,
                isSelf: true
            )
        }
        observers.notify(stories)
    }

    func seed(_ seed: StorySeed) {
        onSeed?(seed)
    }

    func story(id: String) -> PublishedStory? {
        published.first { story in
            story.id == id
        }
    }

    func delete(id: String) {
        guard let index = published.firstIndex(where: { story in
            story.id == id
        }) else {
            return
        }

        let story = published.remove(at: index)
        Self.remove([story.url] + (story.draft?.files ?? []))
        if let mine = stories.firstIndex(where: \.isSelf) {
            let summary = stories[mine]
            stories[mine] = StorySummary(
                peerID: summary.peerID,
                name: summary.name,
                total: max(summary.total - 1, 0),
                unseen: min(summary.unseen, max(summary.total - 1, 0)),
                isSelf: true
            )
        }
        observers.notify(stories)
    }

    private static func remove(_ urls: [URL]) {
        for url in Set(urls) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func observe(_ onChange: @escaping @MainActor @Sendable ([StorySummary]) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(stories)

        return token
    }
}
