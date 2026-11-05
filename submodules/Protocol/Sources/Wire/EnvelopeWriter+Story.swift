internal import FlatBuffers
import Foundation
internal import ProtocolSchema

extension EnvelopeWriter {
    static func writeStory(
        _ story: StoryWireMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch story {
        case .publish(let request):
            return (.storypublish, writePublish(request, into: &builder))
        case .story(let next):
            return (.storydata, writeServerStory(next, into: &builder))
        case .feedGet:
            let start = Airlance_Wire_StoriesGet.startStoriesGet(&builder)

            return (.storiesget, Airlance_Wire_StoriesGet.endStoriesGet(&builder, start: start))
        case .feed(let stories):
            let rows = stories.map { next in
                writeServerStory(next, into: &builder)
            }
            let vector = builder.createVector(ofOffsets: rows)

            return (.storiesdata, Airlance_Wire_StoriesData.createStoriesData(&builder, storiesVectorOffset: vector))
        case .view(let storyID):
            let text = builder.create(string: storyID)

            return (.storyview, Airlance_Wire_StoryView.createStoryView(&builder, storyIdOffset: text))
        case .delete(let storyID):
            let text = builder.create(string: storyID)

            return (.storydelete, Airlance_Wire_StoryDelete.createStoryDelete(&builder, storyIdOffset: text))
        case .changed:
            let start = Airlance_Wire_StoriesChanged.startStoriesChanged(&builder)

            return (.storieschanged, Airlance_Wire_StoriesChanged.endStoriesChanged(&builder, start: start))
        }
    }

    private static func writePublish(
        _ request: StoryPublishRequest,
        into builder: inout FlatBufferBuilder
    ) -> Offset {
        let client = builder.create(string: request.clientID)
        let media = builder.create(string: request.mediaID)
        let cover = builder.create(string: request.coverMediaID)
        let meta = builder.create(string: request.meta)

        return Airlance_Wire_StoryPublish.createStoryPublish(
            &builder,
            clientIdOffset: client,
            mediaIdOffset: media,
            coverMediaIdOffset: cover,
            isVideo: request.isVideo,
            lifetimeHours: request.lifetimeHours,
            metaOffset: meta
        )
    }

    private static func writeServerStory(_ story: ServerStory, into builder: inout FlatBufferBuilder) -> Offset {
        let id = builder.create(string: story.storyID)
        let client = builder.create(string: story.clientID)
        let owner = builder.create(string: story.owner.subject)
        let first = builder.create(string: story.owner.firstName)
        let last = builder.create(string: story.owner.lastName)
        let photo = builder.create(string: story.owner.photoMediaID)
        let video = builder.create(string: story.owner.videoMediaID)
        let media = builder.create(string: story.mediaID)
        let cover = builder.create(string: story.coverMediaID)
        let meta = builder.create(string: story.meta)

        return Airlance_Wire_StoryData.createStoryData(
            &builder,
            storyIdOffset: id,
            clientIdOffset: client,
            ownerSubjectOffset: owner,
            ownerFirstNameOffset: first,
            ownerLastNameOffset: last,
            ownerPhotoMediaIdOffset: photo,
            ownerVideoMediaIdOffset: video,
            mediaIdOffset: media,
            coverMediaIdOffset: cover,
            isVideo: story.isVideo,
            metaOffset: meta,
            createdAtUnix: story.createdAtUnix,
            expiresAtUnix: story.expiresAtUnix,
            seen: story.isSeen,
            viewCount: story.viewCount
        )
    }
}
