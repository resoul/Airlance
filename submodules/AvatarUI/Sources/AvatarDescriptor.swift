import Foundation
import UIKit

public struct AvatarImage: Sendable, Equatable {
    public let key: String

    let load: @Sendable () async -> Data?

    public init(key: String, load: @escaping @Sendable () async -> Data?) {
        self.key = key
        self.load = load
    }

    public init(key: String, data: Data) {
        self.init(key: key) {
            data
        }
    }

    public init(key: String, url: URL) {
        self.init(key: key) {
            await AvatarFileCache.shared.data(for: url, key: key)
        }
    }

    public static func == (lhs: AvatarImage, rhs: AvatarImage) -> Bool {
        lhs.key == rhs.key
    }
}

public struct AvatarVideo: Sendable, Equatable {
    public static let maximumDuration: Double = 10

    public let key: String
    public let url: URL
    public let thumbnailURL: URL?
    public let startTimestamp: Double

    public init(key: String, url: URL, thumbnailURL: URL? = nil, startTimestamp: Double = 0) {
        self.key = key
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.startTimestamp = startTimestamp.isFinite ? max(0, startTimestamp) : 0
    }

    func source(for presentation: AvatarPresentation) -> URL {
        presentation == .list ? thumbnailURL ?? url : url
    }
}

public enum AvatarPresentation: Sendable {
    case still
    case list
    case profile
    case gallery

    var playbackPriority: Int {
        switch self {
        case .still:
            0
        case .list:
            1
        case .profile:
            10
        case .gallery:
            20
        }
    }
}

public struct AvatarDescriptor: Sendable, Equatable {
    public let id: String
    public let initials: String
    public let colors: [UIColor]
    public let image: AvatarImage?
    public let video: AvatarVideo?

    public init(
        id: String,
        initials: String,
        colors: [UIColor]? = nil,
        image: AvatarImage? = nil,
        video: AvatarVideo? = nil
    ) {
        self.id = id
        self.initials = String(initials.prefix(2)).uppercased()
        self.colors = colors ?? AvatarColors.gradient(for: id)
        self.image = image
        self.video = video
    }

    public static func initials(from name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        let letters = words.prefix(2).compactMap(\.first)

        return String(letters)
    }
}
