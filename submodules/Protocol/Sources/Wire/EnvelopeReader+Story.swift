internal import FlatBuffers
import Foundation
internal import ProtocolSchema

extension EnvelopeReader {
    func story(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .storypublish:
            let table: Airlance_Wire_StoryPublish = try checkedRoot(body)

            return .story(.publish(StoryPublishRequest(
                clientID: table.clientId ?? "",
                mediaID: table.mediaId ?? "",
                coverMediaID: table.coverMediaId ?? "",
                isVideo: table.isVideo,
                lifetimeHours: table.lifetimeHours,
                meta: table.meta ?? ""
            )))
        case .storydata:
            let table: Airlance_Wire_StoryData = try checkedRoot(body)

            return .story(.story(Self.serverStory(table)))
        case .storiesget:
            let _: Airlance_Wire_StoriesGet = try checkedRoot(body)

            return .story(.feedGet)
        case .storiesdata:
            let table: Airlance_Wire_StoriesData = try checkedRoot(body)

            return .story(.feed(table.stories.map(Self.serverStory)))
        default:
            return try storyAction(kind: kind, body: body)
        }
    }

    private func storyAction(kind: UInt16, body: Data) throws -> ProtocolMessage {
        switch Airlance_Wire_MessageKind(rawValue: kind) {
        case .storyview:
            let table: Airlance_Wire_StoryView = try checkedRoot(body)

            return .story(.view(storyID: table.storyId ?? ""))
        case .storydelete:
            let table: Airlance_Wire_StoryDelete = try checkedRoot(body)

            return .story(.delete(storyID: table.storyId ?? ""))
        case .storieschanged:
            let _: Airlance_Wire_StoriesChanged = try checkedRoot(body)

            return .story(.changed)
        default:
            return .unsupported(kind: kind)
        }
    }

    private static func serverStory(_ table: Airlance_Wire_StoryData) -> ServerStory {
        ServerStory(
            storyID: table.storyId ?? "",
            clientID: table.clientId ?? "",
            owner: SearchPerson(
                subject: table.ownerSubject ?? "",
                firstName: table.ownerFirstName ?? "",
                lastName: table.ownerLastName ?? "",
                username: "",
                photoMediaID: table.ownerPhotoMediaId ?? "",
                videoMediaID: table.ownerVideoMediaId ?? ""
            ),
            mediaID: table.mediaId ?? "",
            coverMediaID: table.coverMediaId ?? "",
            isVideo: table.isVideo,
            meta: table.meta ?? "",
            createdAtUnix: table.createdAtUnix,
            expiresAtUnix: table.expiresAtUnix,
            isSeen: table.seen,
            viewCount: table.viewCount
        )
    }
}
