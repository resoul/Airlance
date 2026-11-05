import MapKit
import MediaStore
import Stories
import Subtitles
import UIKit

@MainActor
final class AppStoryStudioContext: StoryStudioContext {
    let strings: StoryStudioStrings
    let subtitleStrings: SubtitleStrings
    let locale: Locale
    let autoSubtitles: Bool

    let defaultLifetime: StoryLifetime
    let showsAudienceChoices: Bool

    private let stories: StoriesStore
    private let chats: ChatsStore
    private let media: MediaStore
    private let permissions: PermissionFlow

    init(
        stories: StoriesStore,
        chats: ChatsStore,
        media: MediaStore,
        strings: AppStrings,
        permissions: PermissionFlow,
        autoSubtitles: Bool,
        defaultLifetime: StoryLifetime
    ) {
        self.defaultLifetime = defaultLifetime
        showsAudienceChoices = stories.serverSubject == nil
        self.stories = stories
        self.chats = chats
        self.media = media
        self.permissions = permissions
        self.autoSubtitles = autoSubtitles
        self.strings = .app(strings)
        subtitleStrings = .app(strings)
        locale = strings.pack.locale
    }

    func makeFileURL(extension ext: String) -> URL {
        media.reserve(Self.kind(for: ext), extension: ext).url
    }

    private static func kind(for ext: String) -> LocalMedia.Kind {
        switch ext {
        case "jpg", "png":
            .image
        case "mov", "mp4":
            .video
        case "m4a":
            .voice
        default:
            .file
        }
    }

    func authorizeTranscription(from presenter: UIViewController) async -> Bool {
        await permissions.authorize(.transcribeVoice, from: presenter)
    }

    func authorizeMicrophone(from presenter: UIViewController) async -> Bool {
        await permissions.authorize(.voiceMessage, from: presenter)
    }

    var draftsDirectory: URL {
        MediaStore.directory(for: media.account).appendingPathComponent("StoryDrafts", isDirectory: true)
    }

    var mentionPeers: [StoryMentionPeer] {
        chats.chats
            .filter { chat in
                chat.kind == .person && !chat.isArchived
            }
            .map { chat in
                StoryMentionPeer(id: chat.id, name: chat.name)
            }
    }

    func searchPlaces(_ query: String) async -> [StoryPlace] {
        guard !query.isEmpty else {
            return []
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        let response = try? await MKLocalSearch(request: request).start()

        return (response?.mapItems ?? []).prefix(10).compactMap { item in
            guard let name = item.name else {
                return nil
            }

            let coordinate = item.placemark.coordinate

            return StoryPlace(
                title: name,
                subtitle: item.placemark.locality,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    func publish(_ result: StoryResult) {
        let media: PublishedStory.Media = switch result.media {
        case .photo(let url):
            .photo(url)
        case .video(let url):
            .video(url)
        }
        stories.publish(PublishedStory(
            id: result.draft.id.uuidString,
            media: media,
            audience: result.draft.audience,
            date: Date(),
            widgets: result.draft.entities.filter { entity in
                entity.widget != nil
            },
            aspect: result.draft.aspect,
            draft: result.draft,
            cover: result.cover
        ))
    }
}

extension StoryStudioStrings {
    static func app(_ strings: AppStrings) -> StoryStudioStrings {
        StoryStudioStrings(
            cancel: strings.chatCancel,
            text: strings.storiesText,
            draw: strings.storiesDraw,
            undo: strings.storiesUndo,
            done: strings.storiesDone,
            publish: strings.storiesPublish,
            audience: strings.storiesAudience,
            audiences: [
                .everyone: strings.storiesAudienceEveryone,
                .contacts: strings.storiesAudienceContacts,
                .closeFriends: strings.storiesAudienceCloseFriends,
                .selected: strings.storiesAudienceSelected,
            ],
            subtitles: strings.subtitlesTitle,
            labels: labels(strings)
        )
    }

    static func labels(_ strings: AppStrings) -> [StoryLabel: String] {
        Dictionary(uniqueKeysWithValues: StoryLabel.allCases.map { key in
            (key, strings.pack.string("stories.label." + key.rawValue))
        })
    }
}
