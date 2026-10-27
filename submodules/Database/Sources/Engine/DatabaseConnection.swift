import Foundation
import GRDB

enum DatabaseConnection {
    private static let keyLength = 32

    static func open(_ file: DatabaseFile) throws -> DatabaseQueue {
        try FileManager.default.createDirectory(at: file.directory, withIntermediateDirectories: true)
        let database = try DatabaseQueue(path: file.url.path, configuration: configuration(for: file))
        try protect(file)

        return database
    }

    private static func configuration(for file: DatabaseFile) throws -> Configuration {
        var configuration = Configuration()
        configuration.label = file.name
        configuration.busyMode = .timeout(5)

        if case .key(let key) = file.encryption {
            guard key.count == keyLength else {
                throw DatabaseConnectionError.invalidKeyLength
            }
            let passphrase = rawPassphrase(key)
            configuration.prepareDatabase { db in
                try db.usePassphrase(passphrase)
            }
        }

        return configuration
    }

    private static func rawPassphrase(_ key: Data) -> String {
        let hex = key
            .map { byte in
                String(format: "%02x", byte)
            }
            .joined()

        return "x'\(hex)'"
    }

    private static func protect(_ file: DatabaseFile) throws {
        let fileManager = FileManager.default
        let protection = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]

        try fileManager.setAttributes(protection, ofItemAtPath: file.directory.path)
        for path in file.paths where fileManager.fileExists(atPath: path) {
            try fileManager.setAttributes(protection, ofItemAtPath: path)
        }

        var directory = file.directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = !file.isBackedUp
        try directory.setResourceValues(values)
    }
}

enum DatabaseConnectionError: Error {
    case invalidKeyLength
}
