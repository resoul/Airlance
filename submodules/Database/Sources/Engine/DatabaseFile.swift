import Foundation

struct DatabaseFile: Sendable {
    let directory: URL
    let name: String
    let encryption: DatabaseEncryption
    let isBackedUp: Bool

    var url: URL {
        directory.appendingPathComponent(name, isDirectory: false)
    }

    var paths: [String] {
        let path = url.path

        return [path, path + "-wal", path + "-shm", path + "-journal"]
    }
}
