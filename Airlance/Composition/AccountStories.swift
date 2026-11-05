import CoreGraphics
import Foundation
import MediaStore
import os
import Protocol
import ServerConnection
import Stories

struct StoryServerMeta: Codable, Sendable {
    var caption = ""
    var isProtected = false
    var widgets: [StoryEntity] = []
    var aspectWidth: Double?
    var aspectHeight: Double?

    var aspect: CGSize? {
        guard let aspectWidth, let aspectHeight else {
            return nil
        }

        return CGSize(width: aspectWidth, height: aspectHeight)
    }

    init(_ story: PublishedStory) {
        caption = story.settings.caption
        isProtected = story.settings.isProtected
        widgets = story.widgets
        aspectWidth = story.aspect.map { aspect in
            Double(aspect.width)
        }
        aspectHeight = story.aspect.map { aspect in
            Double(aspect.height)
        }
    }

    static func decode(_ text: String) -> StoryServerMeta? {
        try? JSONDecoder().decode(StoryServerMeta.self, from: Data(text.utf8))
    }

    var encoded: String {
        (try? JSONEncoder().encode(self)).flatMap { data in
            String(data: data, encoding: .utf8)
        } ?? ""
    }
}

@MainActor
final class AccountStories {
    private static let logger = Logger(subsystem: "Airlance", category: "Stories")

    private let connection: ServerConnection
    private let files: ProfileMediaFiles
    private let store: StoriesStore
    private var waiting: [PublishedStory] = []
    private var isSending = false

    init(connection: ServerConnection, files: ProfileMediaFiles, store: StoriesStore) {
        self.connection = connection
        self.files = files
        self.store = store
        store.onPublish = { [weak self] story in
            self?.enqueue(story)
        }
        store.onDelete = { [weak self] clientID, storyID in
            self?.delete(clientID: clientID, storyID: storyID)
        }
        store.onView = { [weak self] storyID in
            self?.view(storyID)
        }
    }

    func refresh() {
        Task {
            await load()
            sendWaiting()
        }
    }

    private func load() async {
        do {
            guard case .story(.feed(let stories)) = try await connection.request(.story(.feedGet)) else {
                return
            }

            register(stories)
            store.setRemote(stories.map(RemoteStory.init))
            prefetch(stories)
        } catch {
            Self.logger.debug("Can't load the stories: \(String(describing: error))")
        }
    }

    private func register(_ stories: [ServerStory]) {
        for story in stories {
            let avatar = RemoteAvatar(
                subject: story.owner.subject,
                username: "",
                photoMediaID: story.owner.photoMediaID,
                videoMediaID: story.owner.videoMediaID,
                files: files
            )
            PeerAvatars.register(avatar, for: story.owner.subject)
        }
    }

    private func prefetch(_ stories: [ServerStory]) {
        let files = files
        for story in stories where story.isVideo {
            let mediaID = story.mediaID
            Task {
                _ = await files.file(mediaID, extension: "mp4")
            }
        }
    }

    private func enqueue(_ story: PublishedStory) {
        waiting.removeAll { item in
            item.id == story.id
        }
        waiting.append(story)
        sendWaiting()
    }

    private func sendWaiting() {
        guard !isSending, let next = waiting.first else {
            return
        }

        isSending = true
        Task {
            do {
                try await send(next)
                waiting.removeAll { item in
                    item.id == next.id && item == next
                }
                isSending = false
                await load()
                sendWaiting()
            } catch {
                Self.logger.error("A story waits to be sent: \(String(describing: error))")
                isSending = false
            }
        }
    }

    private func send(_ story: PublishedStory) async throws {
        let mediaID = try await files.upload(story.url)
        var coverID = ""
        if let cover = story.cover {
            coverID = try await files.upload(cover)
        }
        let isVideo = if case .video = story.media {
            true
        } else {
            false
        }
        let request = StoryPublishRequest(
            clientID: story.id,
            mediaID: mediaID,
            coverMediaID: coverID,
            isVideo: isVideo,
            lifetimeHours: Int32(max(story.settings.lifetime.rawValue, StoryLifetime.hours12.rawValue)),
            meta: StoryServerMeta(story).encoded
        )
        guard case .story(.story) = try await connection.request(.story(.publish(request))) else {
            throw AccountMessagingError.refused
        }
    }

    private func delete(clientID: String?, storyID: String?) {
        waiting.removeAll { item in
            item.id == clientID
        }
        guard let storyID else {
            return
        }

        Task {
            _ = try? await connection.request(.story(.delete(storyID: storyID)))
            await load()
        }
    }

    private func view(_ storyID: String) {
        Task {
            _ = try? await connection.request(.story(.view(storyID: storyID)))
        }
    }
}
