import Foundation
import Security

struct AuthIDToken {
    private struct Header: Decodable {
        let alg: String
        let kid: String?
    }

    private struct Audience: Decodable {
        let values: [String]

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let single = try? container.decode(String.self) {
                values = [single]
            } else {
                values = try container.decode([String].self)
            }
        }
    }

    private struct Claims: Decodable {
        let iss: String
        let sub: String
        let aud: Audience
        let exp: TimeInterval
        let nonce: String?
        let email: String?
    }

    private static let leeway: TimeInterval = 60

    let subject: String
    let email: String?

    static func verify(
        _ token: String,
        nonce: String,
        configuration: AuthConfiguration,
        keys: [AuthKey],
        now: Date = Date()
    ) throws -> AuthIDToken {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else {
            throw AuthError.invalidIDToken("shape")
        }

        let header = try decoded(Header.self, from: parts[0])
        let key = keys.first { key in
            key.kid == header.kid && key.kty == "RSA"
        }
        guard header.alg == "RS256", let key else {
            throw AuthError.invalidIDToken("key")
        }

        guard let signature = AuthBase64URL.decode(parts[2]) else {
            throw AuthError.invalidIDToken("signature")
        }

        try verifySignature(signature, message: Data("\(parts[0]).\(parts[1])".utf8), key: key)
        let claims = try decoded(Claims.self, from: parts[1])
        guard claims.iss == configuration.issuer else {
            throw AuthError.invalidIDToken("issuer")
        }

        guard claims.aud.values.contains(configuration.clientID) else {
            throw AuthError.invalidIDToken("audience")
        }

        guard claims.nonce == nonce else {
            throw AuthError.invalidIDToken("nonce")
        }

        guard Date(timeIntervalSince1970: claims.exp + leeway) > now else {
            throw AuthError.invalidIDToken("expired")
        }

        return AuthIDToken(subject: claims.sub, email: claims.email)
    }

    private static func decoded<Value: Decodable>(_ type: Value.Type, from part: String) throws -> Value {
        guard let data = AuthBase64URL.decode(part), let value = try? JSONDecoder().decode(type, from: data) else {
            throw AuthError.invalidIDToken("encoding")
        }

        return value
    }

    private static func verifySignature(_ signature: Data, message: Data, key: AuthKey) throws {
        guard let modulus = AuthBase64URL.decode(key.n), let exponent = AuthBase64URL.decode(key.e) else {
            throw AuthError.invalidIDToken("key")
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
        ]
        let der = AuthDER.rsaPublicKey(modulus: modulus, exponent: exponent)
        guard
            let publicKey = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil),
            SecKeyVerifySignature(
                publicKey,
                .rsaSignatureMessagePKCS1v15SHA256,
                message as CFData,
                signature as CFData,
                nil
            )
        else {
            throw AuthError.invalidIDToken("signature")
        }
    }
}

enum AuthBase64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ text: String) -> Data? {
        var base64 = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)

        return Data(base64Encoded: base64)
    }
}

enum AuthDER {
    private static let integerTag: UInt8 = 0x02
    private static let sequenceTag: UInt8 = 0x30

    static func rsaPublicKey(modulus: Data, exponent: Data) -> Data {
        element(sequenceTag, content: integer(modulus) + integer(exponent))
    }

    private static func integer(_ value: Data) -> Data {
        let trimmed = value.drop { byte in
            byte == 0
        }
        let needsPadding = (trimmed.first ?? 0) >= 0x80

        return element(integerTag, content: (needsPadding ? Data([0]) : Data()) + trimmed)
    }

    private static func element(_ tag: UInt8, content: Data) -> Data {
        Data([tag]) + length(content.count) + content
    }

    private static func length(_ count: Int) -> Data {
        guard count >= 0x80 else {
            return Data([UInt8(count)])
        }

        var bytes: [UInt8] = []
        var rest = count
        while rest > 0 {
            bytes.insert(UInt8(rest & 0xFF), at: 0)
            rest >>= 8
        }

        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }
}
