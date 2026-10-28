import Foundation

enum KeychainCoder {
    static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        if let data = value as? Data {
            return data
        }

        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw KeychainError.encodingFailed
        }
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        if let value = data as? Value {
            return value
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw KeychainError.decodingFailed
        }
    }
}
