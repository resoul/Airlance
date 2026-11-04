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
        let kind: Airlance_Wire_MessageKind
        let root: Offset
        switch message {
        case .ping(let id):
            kind = .ping
            root = Airlance_Wire_Ping.createPing(&builder, pingId: id)
        case .pong(let id):
            kind = .pong
            root = Airlance_Wire_Pong.createPong(&builder, pingId: id)
        case .error(let error):
            kind = .error
            let text = builder.create(string: error.message)
            root = Airlance_Wire_Error.createError(&builder, code: error.code, messageOffset: text)
        case .profileGet:
            kind = .profileget
            root = Airlance_Wire_ProfileGet.endProfileGet(
                &builder,
                start: Airlance_Wire_ProfileGet.startProfileGet(&builder)
            )
        case .profileSet(let fields):
            kind = .profileset
            root = writeProfileSet(fields, into: &builder)
        case .profileData(let data):
            kind = .profiledata
            root = writeProfileData(data, into: &builder)
        case .authenticate(let token):
            kind = .authenticate
            let text = builder.create(string: token)
            root = Airlance_Wire_Authenticate.createAuthenticate(&builder, accessTokenOffset: text)
        case .authenticated(let expiresAtUnix):
            kind = .authenticated
            root = Airlance_Wire_Authenticated.createAuthenticated(&builder, expiresAtUnix: expiresAtUnix)
        case .unsupported(let raw):
            throw .unencodable(kind: raw)
        }
        builder.finish(offset: root)

        return (kind, builder.data)
    }

    private static func writeProfileSet(_ fields: ProfileFields, into builder: inout FlatBufferBuilder) -> Offset {
        let first = builder.create(string: fields.firstName)
        let last = builder.create(string: fields.lastName)
        let username = builder.create(string: fields.username)
        let bio = builder.create(string: fields.bio)

        return Airlance_Wire_ProfileSet.createProfileSet(
            &builder,
            firstNameOffset: first,
            lastNameOffset: last,
            usernameOffset: username,
            bioOffset: bio
        )
    }

    private static func writeProfileData(_ data: ProfileData, into builder: inout FlatBufferBuilder) -> Offset {
        let subject = builder.create(string: data.subject)
        let first = builder.create(string: data.fields.firstName)
        let last = builder.create(string: data.fields.lastName)
        let username = builder.create(string: data.fields.username)
        let bio = builder.create(string: data.fields.bio)

        return Airlance_Wire_ProfileData.createProfileData(
            &builder,
            subjectOffset: subject,
            firstNameOffset: first,
            lastNameOffset: last,
            usernameOffset: username,
            bioOffset: bio,
            updatedAtUnix: data.updatedAtUnix
        )
    }
}
