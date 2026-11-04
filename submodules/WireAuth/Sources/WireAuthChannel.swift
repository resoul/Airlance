import CryptoKit
import Foundation

public struct WireAuthChannel: Sendable {
    private static let seqSize = 8
    private static let nonceSize = 12
    private static let tagSize = 16

    private let sendKey: SymmetricKey
    private let receiveKey: SymmetricKey
    private var sendSeq: UInt64 = 0
    private var receiveSeq: UInt64 = 0

    init(sendKey: SymmetricKey, receiveKey: SymmetricKey) {
        self.sendKey = sendKey
        self.receiveKey = receiveKey
    }

    public mutating func seal(_ payload: Data) throws -> Data {
        let seqBytes = Self.bigEndian(sendSeq)
        let sealed = try AES.GCM.seal(
            payload,
            using: sendKey,
            nonce: try Self.nonce(seqBytes),
            authenticating: seqBytes
        )
        sendSeq += 1

        return seqBytes + sealed.ciphertext + sealed.tag
    }

    public mutating func open(_ packet: Data) throws -> Data {
        let bytes = Data(packet)
        guard bytes.count >= Self.seqSize + Self.tagSize else {
            throw WireAuthError.packetTooShort
        }

        let seqBytes = Data(bytes.prefix(Self.seqSize))
        guard seqBytes == Self.bigEndian(receiveSeq) else {
            throw WireAuthError.outOfOrder
        }

        let body = bytes.dropFirst(Self.seqSize)
        do {
            let box = try AES.GCM.SealedBox(
                nonce: Self.nonce(seqBytes),
                ciphertext: Data(body.dropLast(Self.tagSize)),
                tag: Data(body.suffix(Self.tagSize))
            )
            let plaintext = try AES.GCM.open(box, using: receiveKey, authenticating: seqBytes)
            receiveSeq += 1

            return plaintext
        } catch {
            throw WireAuthError.decryptionFailed
        }
    }

    private static func nonce(_ seqBytes: Data) throws -> AES.GCM.Nonce {
        try AES.GCM.Nonce(data: Data(repeating: 0, count: nonceSize - seqSize) + seqBytes)
    }

    private static func bigEndian(_ value: UInt64) -> Data {
        withUnsafeBytes(of: value.bigEndian) { bytes in
            Data(bytes)
        }
    }
}
