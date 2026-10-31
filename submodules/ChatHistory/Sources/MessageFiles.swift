import Foundation
import MediaStore

public struct MessageFile: Sendable, Hashable {
    public let name: String
    public let size: Int64
    public let source: MediaSource
    public var isDownloaded: Bool

    public init(name: String, size: Int64, source: MediaSource, isDownloaded: Bool) {
        self.name = name
        self.size = size
        self.source = source
        self.isDownloaded = isDownloaded
    }

    public var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
}

public struct MessageLocation: Sendable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public let title: String?
    public let address: String?

    public init(latitude: Double, longitude: Double, title: String? = nil, address: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        self.address = address
    }
}
