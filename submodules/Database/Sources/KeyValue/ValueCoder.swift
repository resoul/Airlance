import DatabaseAPI
import Foundation
import os

enum ValueCoder {
    private static let logger = Logger(subsystem: "Database", category: "KeyValue")

    static func decode<Value>(_ data: Data?, for key: StorageKey<Value>) -> Value {
        guard let data else {
            return key.defaultValue
        }

        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            logger.error("Can't decode \(key.name, privacy: .public): \(String(describing: error), privacy: .public)")

            return key.defaultValue
        }
    }

    static func encode<Value>(_ value: Value, for key: StorageKey<Value>) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        do {
            return try encoder.encode(value)
        } catch {
            throw StorageError.encodingFailed(key: key.name, underlying: error)
        }
    }
}
