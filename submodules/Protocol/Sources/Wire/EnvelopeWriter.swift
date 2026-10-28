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
        case .unsupported(let raw):
            throw .unencodable(kind: raw)
        }
        builder.finish(offset: root)

        return (kind, builder.data)
    }
}
