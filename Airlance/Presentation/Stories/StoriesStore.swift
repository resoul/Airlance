import Foundation
import Observers
import Protocol
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
    var cover: URL?

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

struct RemoteStory: Sendable, Equatable {
    let id: String
    let clientID: String
    let owner: String
    let ownerName: String
    let mediaID: String
    let coverMediaID: String
    let isVideo: Bool
    let meta: String
    let createdAt: Date
    let expiresAt: Date
    var isSeen: Bool

    init(_ story: ServerStory) {
        id = story.storyID
        clientID = story.clientID
        owner = story.owner.subject
        let parts = [story.owner.firstName, story.owner.lastName].filter { part in
            !part.isEmpty
        }
        ownerName = parts.joined(separator: " ")
        mediaID = story.mediaID
        coverMediaID = story.coverMediaID
        isVideo = story.isVideo
        meta = story.meta
        createdAt = Date(timeIntervalSince1970: TimeInterval(story.createdAtUnix))
        expiresAt = Date(timeIntervalSince1970: TimeInterval(story.expiresAtUnix))
        isSeen = story.isSeen
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
    private(set) var remote: [RemoteStory] = []
    private(set) var serverSubject: String?
    var onSeed: (@MainActor (StorySeed) -> Void)?
    var onPublish: (@MainActor (PublishedStory) -> Void)?
    var onDelete: (@MainActor (_ clientID: String?, _ storyID: String?) -> Void)?
    var onView: (@MainActor (String) -> Void)?

    private let observers = ObserverList<[StorySummary]>()
    private var ownName = ""

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
        let subject = PeerAvatars.server(peerID)?.subject ?? peerID

        return stories.first { story in
            story.peerID == peerID || story.peerID == subject
        }
    }

    func useServer(subject: String, name: String) {
        serverSubject = subject
        ownName = name
        rebuild()
    }

    func setOwnName(_ name: String) {
        guard serverSubject != nil, name != ownName else {
            return
        }

        ownName = name
        rebuild()
    }

    func setRemote(_ next: [RemoteStory]) {
        remote = next
        rebuild()
    }

    func remoteItems(for peerID: String, now: Date) -> [RemoteStory] {
        let kept = Set(published.map(\.id))

        return remote.filter { item in
            item.owner == peerID && item.expiresAt > now && !kept.contains(item.clientID)
        }
    }

    private func rebuild() {
        guard let serverSubject else {
            return
        }

        let now = Date()
        let own = published.filter { story in
            story.isLive(at: now)
        }.count + remoteItems(for: serverSubject, now: now).count
        var next = [StorySummary(peerID: serverSubject, name: ownName, total: own, unseen: 0, isSelf: true)]
        let owners = remote.reduce(into: [String]()) { list, item in
            if item.owner != serverSubject, !list.contains(item.owner) {
                list.append(item.owner)
            }
        }
        for owner in owners {
            let items = remoteItems(for: owner, now: now)
            if let first = items.first {
                let unseen = items.filter { item in
                    !item.isSeen
                }.count
                next.append(StorySummary(peerID: owner, name: first.ownerName, total: items.count, unseen: unseen))
            }
        }
        stories = next
        observers.notify(stories)
    }

    private func markRemoteSeen(_ peerID: String, through item: Int) {
        let items = remoteItems(for: peerID, now: Date())
        let viewed = items.prefix(item + 1).filter { story in
            !story.isSeen
        }
        guard !viewed.isEmpty else {
            return
        }

        for story in viewed {
            onView?(story.id)
            if let index = remote.firstIndex(where: { candidate in
                candidate.id == story.id
            }) {
                remote[index].isSeen = true
            }
        }
        rebuild()
    }

    func markSeen(_ peerID: String, through item: Int) {
        if let serverSubject {
            if peerID != serverSubject {
                markRemoteSeen(peerID, through: item)
            }

            return
        }

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
            publishToServer(story, replacing: old.id)

            return
        }

        published.append(story)
        if serverSubject != nil {
            publishToServer(story, replacing: nil)

            return
        }

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

    private func publishToServer(_ story: PublishedStory, replacing oldID: String?) {
        if let oldID {
            let old = remote.first { item in
                item.clientID == oldID
            }
            onDelete?(nil, old?.id)
            remote.removeAll { item in
                item.clientID == oldID
            }
        }
        onPublish?(story)
        if serverSubject == nil {
            observers.notify(stories)
        } else {
            rebuild()
        }
    }

    func delete(id: String) {
        if serverSubject != nil {
            deleteOnServer(id: id)

            return
        }

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

    private func deleteOnServer(id: String) {
        if let index = published.firstIndex(where: { story in
            story.id == id
        }) {
            let story = published.remove(at: index)
            Self.remove([story.url] + (story.draft?.files ?? []))
        }
        let match = remote.first { item in
            item.id == id || item.clientID == id
        }
        remote.removeAll { item in
            item.id == id || item.clientID == id
        }
        onDelete?(match?.clientID ?? id, match?.id)
        rebuild()
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
