internal import FlatBuffers
import Foundation
internal import ProtocolSchema

enum EnvelopeWriter {
    static func write(_ envelope: ProtocolEnvelope) throws(ProtocolError) -> Data {
        let (kind, body) = try encodeBody(envelope.message)
        var builder = FlatBufferBuilder(initialSize: Int32(clamping: body.count + 64))
        let bodyOffset = builder.createVector(bytes: body)
        let root = Airlance_Wire_Envelope.createEnvelope(
            &builder,
            seq: envelope.seq,
            requestId: envelope.requestID,
            kind: kind.rawValue,
            bodyVectorOffset: bodyOffset
        )
        Airlance_Wire_Envelope.finish(&builder, end: root)

        return builder.data
    }

    private static func encodeBody(
        _ message: ProtocolMessage
    ) throws(ProtocolError) -> (Airlance_Wire_MessageKind, Data) {
        var builder = FlatBufferBuilder(initialSize: 64)
        let (kind, root): (Airlance_Wire_MessageKind, Offset)
        switch message {
        case .ping(let id):
            (kind, root) = (.ping, Airlance_Wire_Ping.createPing(&builder, pingId: id))
        case .pong(let id):
            (kind, root) = (.pong, Airlance_Wire_Pong.createPong(&builder, pingId: id))
        case .error(let error):
            (kind, root) = (.error, writeError(error, into: &builder))
        case .profileGet:
            (kind, root) = (.profileget, writeProfileGet(into: &builder))
        case .profileSet(let fields):
            (kind, root) = (.profileset, writeProfileSet(fields, into: &builder))
        case .profileData(let data):
            (kind, root) = (.profiledata, writeProfileData(data, into: &builder))
        case .profilePhotoAdd(let photoMediaID, let videoMediaID):
            (kind, root) = (.profilephotoadd, writeProfilePhotoAdd(photoMediaID, videoMediaID, into: &builder))
        case .profilePhotoRemove(let photoMediaID):
            (kind, root) = (.profilephotoremove, writeProfilePhotoRemove(photoMediaID, into: &builder))
        case .authenticate(let token):
            (kind, root) = writeAuthenticate(token, into: &builder)
        case .authenticated(let expiresAtUnix):
            (kind, root) = (.authenticated, writeAuthenticated(expiresAtUnix, into: &builder))
        case .updatesSubscribe(let afterSeq):
            (kind, root) = (.updatessubscribe, writeUpdatesSubscribe(afterSeq, into: &builder))
        case .updatesSubscribed(let latestSeq):
            (kind, root) = (.updatessubscribed, writeUpdatesSubscribed(latestSeq, into: &builder))
        case .media(let media):
            (kind, root) = writeMedia(media, into: &builder)
        case .search, .chat, .story, .contact, .privacy:
            (kind, root) = writeFeature(message, into: &builder)
        case .unsupported(let raw):
            throw .unencodable(kind: raw)
        }
        builder.finish(offset: root)

        return (kind, builder.data)
    }

    private static func writeAuthenticated(_ expiresAtUnix: Int64, into builder: inout FlatBufferBuilder) -> Offset {
        Airlance_Wire_Authenticated.createAuthenticated(&builder, expiresAtUnix: expiresAtUnix)
    }

    private static func writeFeature(
        _ message: ProtocolMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch message {
        case .search(let search):
            writeSearch(search, into: &builder)
        case .chat(let chat):
            writeChat(chat, into: &builder)
        case .story(let story):
            writeStory(story, into: &builder)
        case .contact(let contact):
            writeContact(contact, into: &builder)
        case .privacy(let privacy):
            writePrivacy(privacy, into: &builder)
        default:
            (.profileget, writeProfileGet(into: &builder))
        }
    }

    private static func writeMedia(
        _ media: MediaMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch media {
        case .uploadRequest(let size):
            let root = Airlance_Wire_MediaUploadRequest.createMediaUploadRequest(&builder, size: size)

            return (.mediauploadrequest, root)
        case .uploadTicket(let mediaID, let url, let expiresAtUnix):
            let id = builder.create(string: mediaID)
            let address = builder.create(string: url)
            let root = Airlance_Wire_MediaUploadTicket.createMediaUploadTicket(
                &builder,
                mediaIdOffset: id,
                urlOffset: address,
                expiresAtUnix: expiresAtUnix
            )

            return (.mediauploadticket, root)
        case .downloadRequest(let mediaID):
            let id = builder.create(string: mediaID)
            let root = Airlance_Wire_MediaDownloadRequest.createMediaDownloadRequest(&builder, mediaIdOffset: id)

            return (.mediadownloadrequest, root)
        case .downloadTicket(let url, let expiresAtUnix):
            let address = builder.create(string: url)
            let root = Airlance_Wire_MediaDownloadTicket.createMediaDownloadTicket(
                &builder,
                urlOffset: address,
                expiresAtUnix: expiresAtUnix
            )

            return (.mediadownloadticket, root)
        }
    }

    private static func writeUpdatesSubscribe(_ afterSeq: UInt64, into builder: inout FlatBufferBuilder) -> Offset {
        Airlance_Wire_UpdatesSubscribe.createUpdatesSubscribe(&builder, afterSeq: afterSeq)
    }

    private static func writeUpdatesSubscribed(_ latestSeq: UInt64, into builder: inout FlatBufferBuilder) -> Offset {
        Airlance_Wire_UpdatesSubscribed.createUpdatesSubscribed(&builder, latestSeq: latestSeq)
    }

    private static func writeSearch(
        _ search: SearchMessage,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        switch search {
        case .query(let query):
            let text = builder.create(string: query)

            return (.search, Airlance_Wire_Search.createSearch(&builder, queryOffset: text))
        case .results(let people):
            let rows = people.map { person in
                writeSearchPerson(person, into: &builder)
            }
            let vector = builder.createVector(ofOffsets: rows)
            let root = Airlance_Wire_SearchResults.createSearchResults(&builder, peopleVectorOffset: vector)

            return (.searchresults, root)
        case .publicProfileGet(let subject):
            let text = builder.create(string: subject)
            let root = Airlance_Wire_PublicProfileGet.createPublicProfileGet(&builder, subjectOffset: text)

            return (.publicprofileget, root)
        }
    }

    private static func writeSearchPerson(_ person: SearchPerson, into builder: inout FlatBufferBuilder) -> Offset {
        let subject = builder.create(string: person.subject)
        let first = builder.create(string: person.firstName)
        let last = builder.create(string: person.lastName)
        let username = builder.create(string: person.username)
        let photo = builder.create(string: person.photoMediaID)
        let video = builder.create(string: person.videoMediaID)

        return Airlance_Wire_SearchPerson.createSearchPerson(
            &builder,
            subjectOffset: subject,
            firstNameOffset: first,
            lastNameOffset: last,
            usernameOffset: username,
            photoMediaIdOffset: photo,
            videoMediaIdOffset: video
        )
    }

    private static func writeAuthenticate(
        _ token: String,
        into builder: inout FlatBufferBuilder
    ) -> (Airlance_Wire_MessageKind, Offset) {
        let text = builder.create(string: token)

        return (.authenticate, Airlance_Wire_Authenticate.createAuthenticate(&builder, accessTokenOffset: text))
    }

    private static func writeError(_ error: ServerError, into builder: inout FlatBufferBuilder) -> Offset {
        let text = builder.create(string: error.message)

        return Airlance_Wire_Error.createError(&builder, code: error.code, messageOffset: text)
    }

    private static func writeProfileGet(into builder: inout FlatBufferBuilder) -> Offset {
        let start = Airlance_Wire_ProfileGet.startProfileGet(&builder)

        return Airlance_Wire_ProfileGet.endProfileGet(&builder, start: start)
    }

    private static func writeProfileSet(_ fields: ProfileFields, into builder: inout FlatBufferBuilder) -> Offset {
        let first = builder.create(string: fields.firstName)
        let last = builder.create(string: fields.lastName)
        let username = builder.create(string: fields.username)
        let bio = builder.create(string: fields.bio)
        let phone = builder.create(string: fields.phone)
        let photo = builder.create(string: fields.photoMediaID)
        let video = builder.create(string: fields.videoMediaID)

        return Airlance_Wire_ProfileSet.createProfileSet(
            &builder,
            firstNameOffset: first,
            lastNameOffset: last,
            usernameOffset: username,
            bioOffset: bio,
            phoneOffset: phone,
            photoMediaIdOffset: photo,
            videoMediaIdOffset: video
        )
    }

    private static func writeProfileData(_ data: ProfileData, into builder: inout FlatBufferBuilder) -> Offset {
        let subject = builder.create(string: data.subject)
        let first = builder.create(string: data.fields.firstName)
        let last = builder.create(string: data.fields.lastName)
        let username = builder.create(string: data.fields.username)
        let bio = builder.create(string: data.fields.bio)
        let phone = builder.create(string: data.fields.phone)
        let photo = builder.create(string: data.fields.photoMediaID)
        let video = builder.create(string: data.fields.videoMediaID)
        let rows = data.photos.map { photo in
            writeProfilePhoto(photo, into: &builder)
        }
        let photos = builder.createVector(ofOffsets: rows)

        return Airlance_Wire_ProfileData.createProfileData(
            &builder,
            subjectOffset: subject,
            firstNameOffset: first,
            lastNameOffset: last,
            usernameOffset: username,
            bioOffset: bio,
            updatedAtUnix: data.updatedAtUnix,
            phoneOffset: phone,
            photoMediaIdOffset: photo,
            videoMediaIdOffset: video,
            photosVectorOffset: photos
        )
    }

    private static func writeProfilePhoto(_ photo: ProfilePhotoData, into builder: inout FlatBufferBuilder) -> Offset {
        let image = builder.create(string: photo.photoMediaID)
        let video = builder.create(string: photo.videoMediaID)

        return Airlance_Wire_ProfilePhoto.createProfilePhoto(
            &builder,
            photoMediaIdOffset: image,
            videoMediaIdOffset: video,
            addedAtUnix: photo.addedAtUnix
        )
    }

    private static func writeProfilePhotoAdd(
        _ photoMediaID: String,
        _ videoMediaID: String,
        into builder: inout FlatBufferBuilder
    ) -> Offset {
        let image = builder.create(string: photoMediaID)
        let video = builder.create(string: videoMediaID)

        return Airlance_Wire_ProfilePhotoAdd.createProfilePhotoAdd(
            &builder,
            photoMediaIdOffset: image,
            videoMediaIdOffset: video
        )
    }

    private static func writeProfilePhotoRemove(
        _ photoMediaID: String,
        into builder: inout FlatBufferBuilder
    ) -> Offset {
        let image = builder.create(string: photoMediaID)

        return Airlance_Wire_ProfilePhotoRemove.createProfilePhotoRemove(&builder, photoMediaIdOffset: image)
    }
}
