internal import FlatBuffers
import Foundation
internal import ProtocolSchema

struct EnvelopeReader {
    private let options: VerifierOptions

    init(limits: ProtocolLimits) {
        options = VerifierOptions(
            maxDepth: limits.maxDepth,
            maxTableCount: limits.maxTableCount,
            maxApparentSize: UInt32(clamping: limits.maxFrameSize)
        )
    }

    func read(_ data: Data) throws(ProtocolError) -> ProtocolEnvelope {
        let envelope: Airlance_Wire_Envelope
        do {
            envelope = try checkedRoot(data, fileID: Airlance_Wire_Envelope.id)
        } catch {
            throw .invalidEnvelope(reason: String(describing: error))
        }
        let kind = envelope.kind
        let body = envelope.withUnsafePointerToBody { bytes, _ in
            Data(bytes)
        } ?? Data()

        return ProtocolEnvelope(
            seq: envelope.seq,
            requestID: envelope.requestId,
            message: try message(kind: kind, body: body)
        )
    }

    private func message(kind: UInt16, body: Data) throws(ProtocolError) -> ProtocolMessage {
        do {
            switch Airlance_Wire_MessageKind(rawValue: kind) {
            case .ping:
                let ping: Airlance_Wire_Ping = try checkedRoot(body)

                return .ping(id: ping.pingId)
            case .pong:
                let pong: Airlance_Wire_Pong = try checkedRoot(body)

                return .pong(id: pong.pingId)
            case .error:
                let error: Airlance_Wire_Error = try checkedRoot(body)

                return .error(ServerError(code: error.code, message: error.message ?? ""))
            case .profileget:
                let _: Airlance_Wire_ProfileGet = try checkedRoot(body)

                return .profileGet
            case .profileset:
                return try profileSet(body)
            case .profiledata:
                return try profileData(body)
            case .authenticate:
                let table: Airlance_Wire_Authenticate = try checkedRoot(body)

                return .authenticate(token: table.accessToken ?? "")
            case .authenticated:
                let table: Airlance_Wire_Authenticated = try checkedRoot(body)

                return .authenticated(expiresAtUnix: table.expiresAtUnix)
            case .none_, nil:
                return .unsupported(kind: kind)
            }
        } catch {
            throw .invalidBody(kind: kind, reason: String(describing: error))
        }
    }

    private func profileSet(_ body: Data) throws -> ProtocolMessage {
        let set: Airlance_Wire_ProfileSet = try checkedRoot(body)

        return .profileSet(ProfileFields(
            firstName: set.firstName ?? "",
            lastName: set.lastName ?? "",
            username: set.username ?? "",
            bio: set.bio ?? ""
        ))
    }

    private func profileData(_ body: Data) throws -> ProtocolMessage {
        let data: Airlance_Wire_ProfileData = try checkedRoot(body)

        return .profileData(ProfileData(
            subject: data.subject ?? "",
            fields: ProfileFields(
                firstName: data.firstName ?? "",
                lastName: data.lastName ?? "",
                username: data.username ?? "",
                bio: data.bio ?? ""
            ),
            updatedAtUnix: data.updatedAtUnix
        ))
    }

    private func checkedRoot<T: FlatBufferTable & Verifiable>(_ data: Data, fileID: String? = nil) throws -> T {
        var buffer = ByteBuffer(data: data)

        return try getCheckedRoot(byteBuffer: &buffer, fileId: fileID, options: options)
    }
}
