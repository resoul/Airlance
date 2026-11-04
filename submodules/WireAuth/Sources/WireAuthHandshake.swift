import CryptoKit
import Foundation
import Security

public protocol WireAuthTransport: Sendable {
    func sendAndReceive(_ packet: Data) async throws -> Data
}

public struct WireAuthPin: Sendable {
    public let id: UInt32
    public let publicKey: Data

    public init?(id: UInt32, publicKeyBase64: String) {
        guard let key = Data(base64Encoded: publicKeyBase64), key.count == 32 else {
            return nil
        }

        self.id = id
        publicKey = key
    }
}

public enum WireAuthError: Error, Sendable, Equatable {
    case noPins
    case invalidResponse
    case unknownKey
    case invalidSignature
    case invalidServerPublicKey
    case randomFailed
    case packetTooShort
    case outOfOrder
    case decryptionFailed
}

public enum WireAuthHandshake {
    private static let helloCommand: UInt32 = 201
    private static let exchangeCommand: UInt32 = 202
    private static let nonceSize = 16
    private static let keyIDSize = 4
    private static let publicKeySize = 65
    private static let signatureSize = 64
    private static let maxPins = 8
    private static let transcriptLabel = "airlance-wireauth/v3/transcript"
    private static let signatureLabel = "airlance-wireauth/v3/signature"
    private static let clientKeyLabel = "airlance-wireauth/v3/client-to-server"
    private static let serverKeyLabel = "airlance-wireauth/v3/server-to-client"

    public static func establish(
        pins: [WireAuthPin],
        transport: any WireAuthTransport
    ) async throws -> WireAuthChannel {
        guard !pins.isEmpty, pins.count <= maxPins else {
            throw WireAuthError.noPins
        }

        let clientNonce = try randomData(count: nonceSize)
        let hello = helloPacket(nonce: clientNonce, pins: pins)
        let serverHello = try await transport.sendAndReceive(hello)
        guard serverHello.count == nonceSize + keyIDSize else {
            throw WireAuthError.invalidResponse
        }

        let serverNonce = Data(serverHello.prefix(nonceSize))
        let keyID = littleEndianID(Data(serverHello.suffix(keyIDSize)))
        let pin = pins.first { pin in
            pin.id == keyID
        }
        guard let pin else {
            throw WireAuthError.unknownKey
        }

        let privateKey = P256.KeyAgreement.PrivateKey()
        let exchange = littleEndian(exchangeCommand) + privateKey.publicKey.x963Representation
        let reply = try await transport.sendAndReceive(exchange)
        guard reply.count == publicKeySize + signatureSize else {
            throw WireAuthError.invalidResponse
        }

        let serverPublicKey = Data(reply.prefix(publicKeySize))
        let hash = transcriptHash(hello, serverHello, exchange, serverPublicKey)
        try verify(signature: Data(reply.suffix(signatureSize)), hash: hash, pin: pin)

        return try channel(
            privateKey: privateKey,
            serverPublicKey: serverPublicKey,
            salt: clientNonce + serverNonce,
            hash: hash
        )
    }

    private static func helloPacket(nonce: Data, pins: [WireAuthPin]) -> Data {
        var hello = littleEndian(helloCommand) + nonce
        hello.append(UInt8(pins.count))
        for pin in pins {
            hello.append(littleEndian(pin.id))
        }

        return hello
    }

    private static func transcriptHash(_ parts: Data...) -> Data {
        var hasher = SHA256()
        hasher.update(data: Data(transcriptLabel.utf8))
        for part in parts {
            hasher.update(data: part)
        }

        return Data(hasher.finalize())
    }

    private static func verify(signature: Data, hash: Data, pin: WireAuthPin) throws {
        guard
            let key = try? Curve25519.Signing.PublicKey(rawRepresentation: pin.publicKey),
            key.isValidSignature(signature, for: Data(signatureLabel.utf8) + hash)
        else {
            throw WireAuthError.invalidSignature
        }
    }

    private static func channel(
        privateKey: P256.KeyAgreement.PrivateKey,
        serverPublicKey: Data,
        salt: Data,
        hash: Data
    ) throws -> WireAuthChannel {
        let peer: P256.KeyAgreement.PublicKey
        do {
            peer = try P256.KeyAgreement.PublicKey(x963Representation: serverPublicKey)
        } catch {
            throw WireAuthError.invalidServerPublicKey
        }

        let secret = try privateKey.sharedSecretFromKeyAgreement(with: peer)
        let derive = { (label: String) in
            secret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: salt,
                sharedInfo: Data(label.utf8) + hash,
                outputByteCount: 32
            )
        }

        return WireAuthChannel(sendKey: derive(clientKeyLabel), receiveKey: derive(serverKeyLabel))
    }

    private static func randomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw WireAuthError.randomFailed
        }

        return Data(bytes)
    }

    private static func littleEndian(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            Data(bytes)
        }
    }

    private static func littleEndianID(_ data: Data) -> UInt32 {
        data.reversed().reduce(UInt32(0)) { value, byte in
            value << 8 | UInt32(byte)
        }
    }
}
