import Foundation

public enum MediaSource: Sendable, Hashable, Codable {
    case bundle(name: String, ext: String)
    case local(LocalMedia)
    case generated(seed: Int)
    case map(latitude: Double, longitude: Double, isDark: Bool)

    public var isVideo: Bool {
        switch self {
        case .bundle(_, let ext):
            ["mp4", "mov", "m4v"].contains(ext.lowercased())
        case .local(let media):
            media.kind == .video
        case .generated, .map:
            false
        }
    }

    public var isMap: Bool {
        if case .map = self {
            return true
        }

        return false
    }

    public var cacheKey: String {
        switch self {
        case .bundle(let name, let ext):
            "bundle:\(name).\(ext)"
        case .local(let media):
            "local:\(media.account)/\(media.kind.rawValue)/\(media.name)"
        case .generated(let seed):
            "generated:\(seed)"
        case .map(let latitude, let longitude, let isDark):
            "map:\(latitude),\(longitude),\(isDark ? 1 : 0)"
        }
    }

    public var url: URL? {
        switch self {
        case .bundle(let name, let ext):
            Bundle.main.url(forResource: name, withExtension: ext)
        case .local(let media):
            MediaStore.url(for: media)
        case .generated, .map:
            nil
        }
    }
}

public struct LocalMedia: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case image
        case video
        case voice
        case file
    }

    public let account: String
    public let kind: Kind
    public let name: String

    public init(account: String, kind: Kind, name: String) {
        self.account = account
        self.kind = kind
        self.name = name
    }

    public var fileName: String {
        (name as NSString).lastPathComponent
    }
}
